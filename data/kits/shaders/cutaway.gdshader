shader_type spatial;
render_mode cull_disabled;

#define CUTAWAY_DISCARD
#include "player_hole.gdshaderinc"

#include "cutaway.gdshaderinc"
