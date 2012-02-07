# encoding: UTF-8
ActiveRecord::Schema.define(:version => 0) do

  create_table "nodes", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "node_trees", :force => true do |t|
    t.integer  "child_id"
    t.integer  "parent_id"
    t.boolean  "is_active"
    t.date     "effective_on"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
  end

  add_index "node_trees", ["child_id"], :name => "index_node_trees_on_child_id"
  add_index "node_trees", ["parent_id"], :name => "index_node_trees_on_parent_id"
  add_index "node_trees", ["is_active"], :name => "index_node_trees_on_is_active"
  add_index "node_trees", ["effective_on"], :name => "index_node_trees_on_effective_on"
end
