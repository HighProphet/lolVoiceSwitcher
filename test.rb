# require './persisted_config.rb'
# pc = PersistedConfig.new 'test.txt', {dfdf: 'djdjd',wwwwwwwwwwww:'121234567'}, log_lvl: true
# sleep 1
# pc.stop_persistence
require './file_zipper.rb'
Zip.default_compression = Zlib::BEST_COMPRESSION
mission = FileZipMission.new('test.zip', Dir.entries('G:\Development\Ruby\Rubyworks\mping')- %w(. ..))
mission.start