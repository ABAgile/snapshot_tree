$: << File.expand_path('../../lib', __FILE__)

require 'rubygems'
require 'bundler/setup'

require 'pry'

require 'snapshot_tree'

ActiveRecord::Base.establish_connection YAML::load(File.open(File.dirname(__FILE__) + '/db/database.yml'))

class Node < ActiveRecord::Base
  include SnapshotTree::ActsAsTree
  acts_as_tree
  validates :name, presence: true
end

class NodeTree < ActiveRecord::Base
  belongs_to :node
  belongs_to :parent, class_name: 'Node'
  validates :node, :parent, associated: true
  validates :effective_on, :is_active, presence: true
end
