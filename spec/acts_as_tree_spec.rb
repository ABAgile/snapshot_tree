require 'spec_helper'

describe SnapshotTree do

  describe 'after suite setup' do
    it 'should have populated nodes and node_trees' do
      Node.count.should == 15
      NodeTree.count.should == 37
    end
  end

  describe 'when requesting root/leaf nodes' do
    it 'should return a relation' do
      Node.root_nodes.should be_a_kind_of ActiveRecord::Relation
      Node.leaf_nodes.should be_a_kind_of ActiveRecord::Relation
    end

    it 'should allow scope chaining' do
      Node.where(name: 'root_1').first.should   == Node.root_nodes.where(name: 'root_1').first
      Node.where(name: 'node_2_1').first.should == Node.leaf_nodes.where(name: 'node_2_1').first
    end

    it 'should return all root nodes' do
      Node.root_nodes.count.should == 3
      Node.root_nodes(as_of: '1800-01-01').count.should == 15
    end

    it 'should have empty parent node for root nodes' do
      Node.root_nodes.all? { |r| r.parent_node.nil? }.should be true
    end

    it 'should return all leaf nodes' do
      Node.leaf_nodes.count.should == 8
      Node.leaf_nodes(as_of: '1800-01-01').count.should == 15
    end

    it 'should have empty child nodes for leaf nodes' do
      Node.leaf_nodes.all? { |r| r.child_nodes.size == 0 }.should be true
    end
  end

  describe 'when access tree_1' do
    before(:each) do
      @parent = Node.root_nodes.first
    end

    it 'should have 5 descendents and 1 child' do
      @parent.parent_node.should be nil
      @parent.descendent_nodes.size.should == 5
      @parent.child_nodes.size.should == 1
    end

    it 'should have 1 child for each node except the last node' do
      nodes = @parent.descendent_nodes.all
      (nodes.size - 1).times do |i|
        nodes[i].root_node.should == @parent
        nodes[i].parent_node.should == (i > 0 ? nodes[i-1] : @parent)
        nodes[i].child_nodes.size.should == 1
        nodes[i].child_nodes[0].name.should == nodes[i+1].name
      end
      nodes[-1].child_nodes.size.should == 0
    end

    it 'should be a flat tree before year 2000' do
      nodes = @parent.descendent_nodes(as_of: '1990-01-01').where("name ~* 'node_1_'").all
      nodes.all? { |r| r.parent_node(as_of: '1990-01-01') == @parent }.should be true
      nodes.all? { |r| r.child_nodes(as_of: '1990-01-01').where("name ~* 'node_1_'").size == 0 }.should be true
    end

    it 'should be all root nodes before year 1900' do
      nodes = Node.root_nodes(as_of: '1890-01-01').where("name ~* 'root_1|node_1_'").all
      nodes.size.should == 6
      nodes.all? { |r| r.parent_node(as_of: '1890-01-01').nil? }.should be true
    end
  end

  describe 'when access tree_2' do
    before(:each) do
      @parent = Node.root_nodes.where(name: 'root_2').first
    end

    it 'should have 5 descendents and 5 child' do
      @parent.parent_node.should be nil
      @parent.descendent_nodes.size.should == 5
      @parent.child_nodes.size.should == 5
    end

    it 'should have no child for each node' do
      nodes = @parent.descendent_nodes.all
      nodes.size.times do |i|
        nodes[i].root_node.should == @parent
        nodes[i].parent_node.should == @parent
        nodes[i].child_nodes.size.should == 0
      end
    end

    it 'should be all child of root_1 before year 2000' do
      root_1 = Node.where(name: 'root_1').first
      nodes = @parent.descendent_nodes(as_of: '1990-01-01').where("name ~* 'node_2_'").all
      nodes.all? { |r| r.parent_node(as_of: '1990-01-01') == root_1 }.should be true
      nodes.all? { |r| r.child_nodes(as_of: '1990-01-01').size == 0 }.should be true
    end
  end

  describe 'when access tree_3' do
    before(:each) do
      @parent = Node.root_nodes.where(name: 'root_3').first
    end

    it 'should have 2 descendents and 2 child' do
      @parent.parent_node.should be nil
      @parent.descendent_nodes.size.should == 2
      @parent.child_nodes.size.should == 2
    end

    it 'should have no child for each node' do
      nodes = @parent.descendent_nodes.all
      nodes.size.times do |i|
        nodes[i].root_node.should == @parent
        nodes[i].parent_node.should == @parent
        nodes[i].child_nodes.size.should == 0
      end
    end

    it 'should be respect the snapshot history' do
      node = Node.where(name: 'node_3_1').first
      node.parent_node(as_of:'1901-01-01').name.should == 'node_1_1'
      node.parent_node(as_of:'1911-01-01').name.should == 'node_1_2'
      node.parent_node(as_of:'1921-01-01').name.should == 'node_1_3'
      node.parent_node(as_of:'1931-01-01').name.should == 'node_1_4'
      node.parent_node(as_of:'1941-01-01').name.should == 'node_1_5'
      node.parent_node(as_of:'2010-01-01').name.should == 'root_3'
    end

    it 'should be respect the active status of snapshot history' do
      node = Node.where(name: 'node_3_2').first
      node.parent_node(as_of:'1901-01-01').name.should == 'node_1_1'
      node.parent_node(as_of:'1911-01-01').name.should == 'node_1_1'
      node.parent_node(as_of:'1921-01-01').name.should == 'node_1_3'
      node.parent_node(as_of:'1931-01-01').name.should == 'node_1_3'
      node.parent_node(as_of:'1941-01-01').name.should == 'node_1_5'
      node.parent_node(as_of:'2010-01-01').name.should == 'root_3'
    end
  end

  #
  # db setup for the whole test suite
  #
  before(:all) do
    if Node.table_exists? && NodeTree.table_exists?
      NodeTree.delete_all
      Node.delete_all
      Node.connection.execute("select setval('nodes_id_seq', 1, false); select setval('node_trees_id_seq', 1, false);")
    else
      load(File.dirname(__FILE__) + '/db/schema.rb')
    end

    # for testing multi-level hierarchy
    parent1 = Node.create(name: "root_1")
    node = Node.new(name: "node_1_1")
    node.parent_tree_nodes.build(parent_id: parent1.id, effective_on: '1900-01-01')
    node.save!
    nodes = [node]
    4.times do |i|
      node = Node.new(name: "node_1_#{i + 2}")
      node.parent_tree_nodes.build(parent_id: nodes[i].id, effective_on: '2000-01-01')
      node.parent_tree_nodes.build(parent_id: parent1.id, effective_on: '1900-01-01')
      node.save!
      nodes << node
    end

    # for testing single-level hierarchy
    parent2 = Node.create(name: "root_2")
    5.times do |i|
      node = Node.new(name: "node_2_#{i + 1}")
      node.parent_tree_nodes.build(parent_id: parent2.id, effective_on: '2000-01-01')
      node.parent_tree_nodes.build(parent_id: parent1.id, effective_on: '1900-01-01')
      node.save!
    end

    parent3 = Node.create(name: "root_3")

    # testing effective snapshot
    node = Node.new(name: "node_3_1")
    node.parent_tree_nodes.build(parent_id: nodes[0].id, effective_on: '1900-01-01')
    node.parent_tree_nodes.build(parent_id: nodes[1].id, effective_on: '1910-01-01')
    node.parent_tree_nodes.build(parent_id: nodes[2].id, effective_on: '1920-01-01')
    node.parent_tree_nodes.build(parent_id: nodes[3].id, effective_on: '1930-01-01')
    node.parent_tree_nodes.build(parent_id: nodes[4].id, effective_on: '1940-01-01')
    node.parent_tree_nodes.build(parent_id: parent1.id, effective_on: '2000-01-01', created_at: Time.now - 2.hour)
    node.parent_tree_nodes.build(parent_id: parent2.id, effective_on: '2000-01-01', created_at: Time.now - 1.hour)
    node.parent_tree_nodes.build(parent_id: parent3.id, effective_on: '2000-01-01')
    node.save!

    # testing active snapshot
    node = Node.new(name: "node_3_2")
    node.parent_tree_nodes.build(parent_id: nodes[0].id, effective_on: '1900-01-01')
    node.parent_tree_nodes.build(parent_id: nodes[1].id, effective_on: '1910-01-01')
    node.parent_tree_nodes.build(parent_id: nodes[2].id, effective_on: '1920-01-01')
    node.parent_tree_nodes.build(parent_id: nodes[3].id, effective_on: '1930-01-01')
    node.parent_tree_nodes.build(parent_id: nodes[4].id, effective_on: '1940-01-01')
    node.parent_tree_nodes.build(parent_id: nodes[0].id, effective_on: '2000-01-01', created_at: Time.now - 4.hour)
    node.parent_tree_nodes.build(parent_id: nodes[1].id, effective_on: '2000-01-01', created_at: Time.now - 3.hour)
    node.parent_tree_nodes.build(parent_id: nodes[2].id, effective_on: '2000-01-01', created_at: Time.now - 2.hour)
    node.parent_tree_nodes.build(parent_id: parent3.id,  effective_on: '2000-01-01', created_at: Time.now - 1.hour)
    node.parent_tree_nodes.build(parent_id: parent1.id,  effective_on: '2000-01-01')
    node.save!
    NodeTree.where(child_id: node.id, parent_id: nodes[1].id).first.update_attribute(:is_active, false)
    NodeTree.where(child_id: node.id, parent_id: nodes[3].id).first.update_attribute(:is_active, false)
    NodeTree.where(child_id: node.id, parent_id: parent1.id).first.update_attribute(:is_active, false)
  end

end
