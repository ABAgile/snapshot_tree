module SnapshotTree
  module ActsAsTree
    extend ActiveSupport::Concern

    def descendent_nodes(*args)
      self.class.descendent_nodes(id, *args)
    end

    alias_method :descendant_nodes, :descendent_nodes

    def ancestor_nodes(*args)
      self.class.ancestor_nodes(id, *args)
    end

    def root_node?(*args)
      self.class.root_nodes(id, *args).where(id: id).size > 0
    end

    def leaf_node?(*args)
      self.class.leaf_nodes(id, *args).where(id: id).size > 0
    end

    def root_node(*args)
      if root_node?(*args)
        self
      else
        ancestor_nodes(*args).limit(1).first
      end
    end

    def parent_node(*args)
      ancestor_nodes(*args).try(:last)
    end

    def child_nodes(*args)
      opts = args.detect { |x| x.is_a?(Hash) }
      opts ? opts.merge!(depth: 1) : args << {depth: 1}

      descendent_nodes(*args)
    end

    module ClassMethods
      def acts_as_tree(opts = {})
        options = {
          parent_key:      :parent_id,
          child_key:       :child_id,
          snapshot_field:  :effective_on,
          is_active_field: :is_active,
          node_prefix:     :node,
          dependent:       :nullify
        }.merge(opts)

        options[:model_class] = self.name
        options[:model_table] = options[:model_class].tableize
        options[:join_class]  = "#{self.name}Tree" unless options[:join_class]
        options[:join_class]  = options[:join_class].to_s
        options[:join_table]  = options[:join_class].tableize

        instance_variable_set :@tree_helper, TreeHelper.new(options)

        has_many :parent_tree_nodes,
          -> { where(options[:is_active_field].to_sym => true) if options[:is_active_field] },
          class_name:  options[:join_class],
          foreign_key: options[:child_key],
          autosave:    true,
          dependent:   options[:dependent]

        has_many :child_tree_nodes,
          -> { where(optoins[:is_active_field].to_sym => true) if options[:is_active_field] },
          class_name:  options[:join_class],
          foreign_key: options[:parent_key],
          autosave:    true,
          dependent:   options[:dependent]

        "#{options[:node_prefix]}_depth".to_sym.tap do |field|
          define_method(field) do
            read_attribute(field).try(:to_i)
          end
        end

        "#{options[:node_prefix]}_path".to_sym.tap do |field|
          define_method(field) do
            read_attribute(field).gsub(/[{}]/, '').split(',').map(&:to_i) if read_attribute(field)
          end
        end
      end

      def root_nodes(*args)
        opts = @tree_helper.parse_args(*args)

        sql = @tree_helper.nodes_query(:root)
        sql = sql.gsub(/__snapshot_value__/, opts[:as_of].to_s(format: :db)) if @tree_helper.snapshot_field?

        self.unscoped.from(sql).order('1')
      end

      def leaf_nodes(*args)
        opts = @tree_helper.parse_args(*args)

        sql = @tree_helper.nodes_query(:leaf)
        sql = sql.gsub(/__snapshot_value__/, opts[:as_of].to_s(format: :db)) if @tree_helper.snapshot_field?

        self.unscoped.from(sql).order('1')
      end

      def descendent_nodes(*args)
        opts = @tree_helper.parse_args(*args)

        sql = @tree_helper.nodes_query(:descendent)
        sql = sql.gsub(/__model_id__/, opts[:model_id].to_s)
        sql = sql.gsub(/__snapshot_value__/, opts[:as_of].to_s(format: :db)) if @tree_helper.snapshot_field?

        query = self.unscoped.from(sql)
        query = query.where("#{@tree_helper.node_field(:depth)} <= #{opts[:depth]}") if opts[:depth] > 0
        query = query.order("#{@tree_helper.node_field(:path)}")
      end

      alias_method :descendant_nodes, :descendent_nodes

      def ancestor_nodes(*args)
        opts = @tree_helper.parse_args(*args)

        sql = @tree_helper.nodes_query(:ancestor)
        sql = sql.gsub(/__model_id__/, opts[:model_id].to_s)
        sql = sql.gsub(/__snapshot_value__/, opts[:as_of].to_s(format: :db)) if @tree_helper.snapshot_field?

        query = self.unscoped.from(sql)
        query = query.where("#{@tree_helper.node_field(:depth)} <= #{opts[:depth]}") if opts[:depth] > 0
        query = query.order("#{@tree_helper.node_field(:depth)} DESC")
      end
    end

    class TreeHelper
      def initialize(opts)
        @opts = opts
        @query = {}
        @template = YAML::load(File.open(File.dirname(__FILE__) + '/template.yml'))
      end

      def nodes_query(query_type)
        return @query[query_type] if @query[query_type]

        @query[query_type] = Handlebars::Context.new.compile(
          @template["#{query_type}_query"]
        ).call(
          {
            model_table:     @opts[:model_table],
            join_table:      @opts[:join_table],
            child_key:       "#{@opts[:child_key]}",
            parent_key:      "#{@opts[:parent_key]}",
            path:            "#{@opts[:node_prefix]}_path",
            depth:           "#{@opts[:node_prefix]}_depth",
            cycle:           "#{@opts[:node_prefix]}_cycle",
            snapshot_field:  "#{@opts[:snapshot_field]}",
            is_active_field: "#{@opts[:is_active_field]}"
          }
        )
      end

      def node_field(field)
        "#{@opts[:model_table]}.#{@opts[:node_prefix]}_#{field}"
      end

      def snapshot_field?
        @opts[:snapshot_field].present?
      end

      def parse_args(*args)
        opts = args.detect { |x| x.is_a?(Hash) } || {}
        args.delete(opts) if opts.size > 0
        opts[:as_of]    = opts[:as_of].respond_to?(:to_date) ? opts[:as_of].to_date : Date.today
        opts[:depth]    = opts[:depth].to_i
        opts[:model_id] = args[0].is_a?(ActiveRecord::Base) ? args[0].id : args[0].to_i
        opts
      end

    end
  end
end
