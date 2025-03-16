class CreateConversionRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :conversion_requests do |t|
      t.string :source_platform, null: false
      t.string :source_url, null: false
      t.boolean :successful, default: false

      t.timestamps
    end

    add_index :conversion_requests, :source_platform
    add_index :conversion_requests, :created_at
  end
end
