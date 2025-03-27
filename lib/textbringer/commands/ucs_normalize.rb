module Textbringer
  module Commands
    define_command(:ucs_normalize_nfc_region,
                   doc: <<~EOD) do
        Compose the region according to the Unicode NFC.
      EOD
      Buffer.current.replace_region do |s|
        s.unicode_normalize(:nfc)
      end
    end

    define_command(:ucs_normalize_nfd_region,
                   doc: <<~EOD) do
        Decompose the region according to the Unicode NFD.
      EOD
      Buffer.current.replace_region do |s|
        s.unicode_normalize(:nfd)
      end
    end

    define_command(:ucs_normalize_nfkc_region,
                   doc: <<~EOD) do
        Compose the region according to the Unicode NFKC.
      EOD
      Buffer.current.replace_region do |s|
        s.unicode_normalize(:nfkc)
      end
    end

    define_command(:ucs_normalize_nfkd_region,
                   doc: <<~EOD) do
        Decompose the region according to the Unicode NFKD.
      EOD
      Buffer.current.replace_region do |s|
        s.unicode_normalize(:nfkd)
      end
    end
  end
end
