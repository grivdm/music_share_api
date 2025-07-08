FactoryBot.define do
  factory :track do
    sequence(:isrc) { |n| "US7VG#{n.to_s.rjust(7, '0')}" }
    sequence(:title) { |n| "Test Track #{n}" }
    artist { "Test Artist" }
    album { "Test Album" }
    duration { 180 }
    release_year { 2022 }
  end
end
