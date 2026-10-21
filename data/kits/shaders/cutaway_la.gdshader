// Paredes de los kits LA: el cutaway sin discard. En las mazmorras LA no hay corte de la pared sur ni agujero del player,
// y un discard que nunca corre igual apaga el descarte temprano de píxeles tapados en las GPU de celular (15.23).
// Las caras de atrás no se ven desde la cámara fija: cull_back ahorra su costo (mismas capturas en todas las salas).
shader_type spatial;
render_mode cull_back;

#include "player_hole.gdshaderinc"
#include "cutaway.gdshaderinc"
