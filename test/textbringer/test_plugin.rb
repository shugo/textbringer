require_relative "../test_helper"

class TestMode < Textbringer::TestCase
  module FindFilesExt
    @@files = nil

    def self.files=(files)
      @@files = files
    end

    def find_latest_files(*args)
      @@files || super(*args)
    end
  end

  Gem.singleton_class.prepend(FindFilesExt)

  teardown do
    FindFilesExt.files = nil
  end

  def test_load_plugins
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.expand_path("foo-0.9.0/lib", dir))
      foo_0_9_0 = File.expand_path("foo-0.9.0/lib/textbringer_plugin.rb", dir)
      File.write(foo_0_9_0, <<~EOF)
        $FOO_VERSION = "0.9.0"
      EOF
      FileUtils.mkdir_p(File.expand_path("foo-0.10.0/lib", dir))
      foo_0_10_0 =
        File.expand_path("foo-0.10.0/lib/textbringer_plugin.rb", dir)
      File.write(foo_0_10_0, <<~EOF)
        $FOO_VERSION = "0.10.0"
      EOF
      FileUtils.mkdir_p(File.expand_path("bar-0.1.0/lib", dir))
      bar_0_1_0 = File.expand_path("bar-0.1.0/lib/textbringer_plugin.rb", dir)
      File.write(bar_0_1_0, <<~EOF)
        $BAR_VERSION = "0.1.0"
      EOF

      FindFilesExt.files = [foo_0_10_0, bar_0_1_0]

      baz = File.expand_path("non_gem_plugins/baz/textbringer_plugin.rb", dir)
      FileUtils.mkdir_p(File.dirname(baz))
      File.write(baz, <<~EOF)
        $BAZ_VERSION = "0.1.0dev"
      EOF

      Plugin.directory = File.expand_path("non_gem_plugins", dir)
      
      Plugin.load_plugins
      assert_equal("0.10.0", $FOO_VERSION)
      assert_equal("0.1.0", $BAR_VERSION)
      assert_equal("0.1.0dev", $BAZ_VERSION)
    end
  end
end
