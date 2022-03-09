-- character ROM
--   - 8-by-16 (8-by-2^4) font
--   - 128 (2^7) characters
--   - ROM size: 512-by-8 (2^11-by-8) bits
--               16K bits: 1 BRAM
-- from https://github.com/Derek-X-Wang/VGA-Text-Generator/blob/master/VGA-Text-Generator.srcs/sources_1/new/Font_Rom.vhd
-- 

package font_en_crt_pkg is 
	constant FONT_WIDTH : integer := 8;
	constant FONT_HEIGHT : integer := 16;
end package font_en_crt_pkg;

package body font_en_crt_pkg is 
end package body font_en_crt_pkg;


