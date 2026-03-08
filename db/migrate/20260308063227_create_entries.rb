class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries do |t|
      t.text :content
      t.integer :role

      t.timestamps
    end
  end
end
