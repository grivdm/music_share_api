FactoryBot.define do
  factory :track do
    isrc { "US7VG1234567" }
    title { "Test Track" }
    artist { "Test Artist" }
    album { "Test Album" }
    duration { 180 }
    release_year { 2022 }
  end
end
