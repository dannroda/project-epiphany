// Paredes de los kits LA: el cutaway sin discard. En las mazmorras LA no hay corte de la pared sur ni agujero del player,
// y un discard que nunca corre igual apaga el descarte temprano de píxeles tapados en las GPU de celular (15.23).
shader_type spatial;
render_mode cull_disabled;

#include "player_hole.gdshaderinc"
#include "cutaway.gdshaderinc"
