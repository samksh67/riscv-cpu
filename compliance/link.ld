/*
 * Relocated riscv-tests link script.
 *
 * Upstream (env/p/link.ld) places everything at 0x80000000, which is where
 * spike/HTIF-style simulators map physical memory. This core's PC resets to
 * 0, so the whole image is relocated to start there instead. Everything
 * else (section order, 0x1000 alignment between sections) is left as
 * upstream has it.
 */
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;
  .text.init : { *(.text.init) }
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }
  . = ALIGN(0x1000);
  .text : { *(.text) }
  . = ALIGN(0x1000);
  .data : { *(.data) }
  .data.string : { *(.data.string) }
  .bss : { *(.bss) }
  _end = .;
}
