class CreateTracks < ActiveRecord::Migration[8.0]
  def change
    create_table :tracks do |t|
      t.string :isrc, null: false
      t.string :title, null: false
      t.string :artist, null: false
      t.string :album
      t.integer :duration
      t.integer :release_year

      t.timestamps
    end

    add_index :tracks, :isrc, unique: true
    add_index :tracks, [ :artist, :title ]
  end
end
