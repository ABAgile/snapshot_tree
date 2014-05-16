# Snapshot Tree

Yet another tree implementation of adjacency list structure using recursive query of Postgresql >= 8.4.

The main implementation different among others similar gems is the support
of handling multiple effective tree snapshot, for which the parent/child relationship
history can all be kept in a single relationship table with different effective date.

Since ActiveRecord doesn't support update of relation table through has_many :through association,
the creation of child and parent directly through association are not suported by this gem.
Please reference other gems in case if multiple snapshot with effective date handling is not necessary.

## Requirements

* PostgreSQL version >= 8.4
* ActiveRecord

## Setup

1.  Add this line to your application's Gemfile: ```gem 'snapshot_tree'```

2.  Run ```bundle install```

3.  Add ```acts_as_tree``` to your hierarchical model(s), see configuration section below.

    The ActiveRecord associations ```parent_tree_nodes``` and ```child_tree_nodes``` will be
    added automatically to ease the creation of tree association records

    ```ruby
    class Node < ActiveRecord::Base
      include SnapshotTree::ActsAsTree
      acts_as_tree
    end
    ```

4.  Add a database migration to store the hierarchy relation for your model.
    Relation table's name must be the model's table name, followed by "_tree".

    ```ruby
    class CreateModelTrees < ActiveRecord::Migration
      def change
        create_table :model_trees do |t|
          t.integer  :child_id
          t.integer  :parent_id
          t.boolean  :is_active       # default field name for :is_active_field option
          t.date     :effective_on    # default field name for :snapshot_field option

          t.timestamps
        end
      end
    end
    ```

5.  Run ```rake db:migrate```

## Configuration

When you include ```acts_as_tree``` in your model, you can provide a hash to override the following defaults:

* ```:child_key``` to override the column name of the child foreign key in relation table. (default: ```child_id```)
* ```:parent_key``` to override the column name of the parent foreign key in relation table. (default: ```parent_id```)
* ```:node_prefix``` to override the field name prefix of generated field after getting descendent_nodes or ancestor_nodes. (default: ```node```) 
* ```:snapshot_field``` to override the column name of snapshot effective date in relations table. (default: ```effective_on```)
    - set it to ```nil``` will disable effective date filtering when getting tree snapshot.
* ```:is_active_field``` to override the column name of snapshot record active status in relation table. (default: ```is_active```)
    - set it to ```nil``` will disable active status checking.
* ```:dependent``` determines what happens when a node is destroyed. Defaults to ```nullify```.
    * ```:nullify``` will simply set the parent column to null. Each child node will be considered a "root" node. This is the default.
    * ```:delete_all``` will delete all descendant nodes (which circumvents the destroy hooks)
    * ```:destroy``` will destroy all descendant nodes (which runs the destroy hooks on each child node)

## Usage

### Creation tree association:

  ```ruby
  grandpa = Node.create(:name => 'grandpa')
  parent  = Node.create(:name => 'parent')
  child   = Node.create(:name => 'child')

  grandpa.child_tree_nodes.create(:child_id => parent.id, :effective_on => '2012-01-01')
  child.parent_tree_nodes.create(:parent_id => parent.id, :effective_on => Date.today)

  ```

Accessing the tree:

#### Class methods

* ```Node.root_nodes``` returns all root nodes
* ```Node.leaf_nodes``` returns all leaf nodes
* ```Node.descendent_nodes``` returns all descendent nodes, including children, children's children, ... etc.
* ```Node.ancestor_nodes``` returns all ancestor nodes, including parent, grandparent, great grandparent, ... etc.

#### Instance methods

* ```Node.root_node``` returns the root node for this node
* ```Node.root_node?``` returns true if this is a root node
* ```Node.leaf_node?``` returns true if this is a leaf node
* ```Node.parent_node``` returns the parent node for this node
* ```Node.child_nodes``` returns an array of direct children node for this node
* ```Node.descendent_nodes``` returns all descendent nodes for this node, including children, children's children, ... etc.
* ```Node.ancestor_nodes``` returns all ancestor nodes for this node, including parent, grandparent, great grandparent, ... etc.

#### Extra options

When calling the instance/class methods, you can pass a hash of options to override the default behavour:

* ```:as_of``` to query the snapsot tree as of specify effective date, the latest effective date <= this parameter will be used to filter records. This defaults to today.
* ```:depth``` to limit to number of level to query, 0 for all levels, 1 for direct children only, 2 for direct children and grand children, ... etc. This defaults to 0.

When calling the class methods, you must pass an model or model id in order to query tree nodes:

```Node.descendent_nodes(grandpa, :depth => 1, :as_of => '2010-01-01')```


## Gem testing

1. Copy spec/database.yml.sample to spec/database.yml and edit to appropriate values
2. Create table 'tree_testing'
3. Run ```load 'spec/db/schema.rb'``` in console
4. ```bundle exec rspec spec/acts_as_tree_spec.rb```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Thanks to

* https://github.com/chrisroberts/acts_as_sane_tree

* https://github.com/mceachen/closure_tree

* [Bill Karwin](http://karwin.blogspot.com/)'s excellent
[Models for hierarchical data presentation](http://www.slideshare.net/billkarwin/models-for-hierarchical-data)
for a description of different tree storage algorithms.
