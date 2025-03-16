class CreatePlatformTracks < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_tracks do |t|
      t.references :track, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :platform_id, null: false
      t.string :url, null: false

      t.timestamps
    end

    add_index :platform_tracks, [ :platform, :platform_id ], unique: true
    add_index :platform_tracks, [ :track_id, :platform ], unique: true
  end
end
