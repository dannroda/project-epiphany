# GDD — [Título provisorio] — Godot Wild Jam #97
**Tema:** Imminent Doom | **Duración de jam:** 7 días | **Motor:** Godot 4.7+

---

## 1. Pitch

Un mini-dungeon de puzzles top-down, con cámara inclinada al estilo *Link's Awakening* (Switch remake) — se juega como si fuera 2D pero está construido en 3D. El jugador explora un templo antiguo mientras algo (a definir: meteorito / mago malvado) se acerca al fin del mundo. Al final del templo espera un guardián: un ojo flotante con manos.

El tema "Imminent Doom" se transmite **por ambientación y narrativa**, no por mecánica de timer ni colapso forzado. Backtracking libre permitido.

---

## 2. Pilares de diseño

1. **Scope controlado por sobre ambición.** Prioridad: un juego corto y pulido > un juego largo a medio terminar.
2. **Doom se siente, no se cronometra.** Sin timers jugables ni colapso de salas. La tensión viene de arte, audio y narrativa ambiental.
3. **Espada y escudo hacen doble función.** El escudo no es solo defensa — se usa también en puzzles (reflejar, resistir).
4. **Reutilización inteligente.** El jefe (ojo con manos) viene de otra jam — ahorra tiempo de arte/rig para invertirlo en salas y pulido.

---

## 3. Ambientación / Historia

*(Pendiente decidir entre dos variantes — ambas compatibles con el ojo con manos como jefe)*

**Opción A — El Ojo despierta:** El templo sella a un ente antiguo (el ojo). A medida que el jugador avanza, el ojo va despertando y el templo empieza a mostrar signos del fin que se acerca (grietas, luz cambiante, temblores lejanos). El jugador debe llegar a sellarlo de nuevo antes de que despierte del todo.

**Opción B — El Ojo ve el fin:** Un meteorito/cataclismo se acerca al mundo. El ojo es un oráculo/guardián que ha estado observando su llegada durante siglos y ahora, al borde de la locura por lo que ve, ataca a quien se acerque — hay que atravesarlo para llegar a algo que puede detener o mitigar el desastre (una reliquia, un ritual).

> Recomendación: Opción A es más autocontenida (no depende de explicar un meteorito externo) y el ojo mismo es la fuente y el símbolo del doom — más coherente en poco texto/cutscenes.

**Progresión narrativa ambiental (sala por sala):**
- Salas iniciales: calma, templo silencioso, algo de luz natural.
- Salas medias: primeras grietas, polvo cayendo, sonido lejano (rugido, latido, murmullo).
- Salas finales: luz rojiza/anómala, temblores más frecuentes, el "murmullo" del ojo se vuelve casi audible.
- Sala del jefe: clímax visual y sonoro — el doom está "ahí", en la cara del jugador.

---

## 4. Cámara y control

- **Cámara:** top-down inclinada, fija por sala (no sigue al jugador en scroll continuo, corta entre salas como en Link's Awakening).
- **Movimiento:** libre en 8 direcciones (no grilla estricta) para que se sienta más fluido que Zelda NES pero mantenga la legibilidad 2D.
- **Input:** pensado para gamepad y teclado. Sin aiming analógico complejo (se descartó por la decisión de no ir a side-scroller/metroidvania).

---

## 5. Combate

- **Arma inicial y única para la jam:** espada (ataque cuerpo a cuerpo, sin combo complejo — 1 ataque + posible stab cargado si el tiempo lo permite) + escudo.
- **Escudo — doble función:**
  - Combate: bloqueo de ataques melee del jefe/enemigos.
  - Puzzle: reflejar proyectiles (ej. ataques a distancia del ojo) hacia interruptores o hacia el propio jefe.
- **Post-jam (fuera de scope ahora):** bombas y arco con flechas. Requieren sistema de inventario/selector de ítems — deliberadamente pospuesto para no sumar complejidad de UI/UX en la semana de jam.

---

## 6. Estructura del templo

**6-7 salas + 1 sala de jefe.** Dificultad y densidad de ambientación creciente.

| Sala | Tipo de puzzle | Combate | Nota de ambientación |
|------|----------------|---------|----------------------|
| 1 — Entrada | Tutorial suave: empujar un bloque, primer interruptor | Ninguno | Templo tranquilo, luz natural |
| 2 | Línea de visión / espejos o palancas que abren una puerta | Enemigo básico opcional (melee simple) | Primeras grietas visibles en paredes |
| 3 | Puzzle de escudo: reflejar un proyectil de una trampa hacia un blanco | 1-2 enemigos que enseñan el bloqueo | Polvo cae del techo al resolver |
| 4 | Combinación de bloques + interruptor en orden | Enemigo que obliga a alternar ataque/bloqueo | Temblor breve, sonido lejano del ojo |
| 5 | Puzzle que combina lo aprendido (bloques + reflejo con escudo) | Mini-oleada de 2-3 enemigos | Luz empieza a virar a tono rojizo |
| 6 — Previa al jefe | Puzzle final de preparación (opcional: sala de "práctica" contra ataques tipo jefe en pequeña escala) | — | Pasillo con murmullo audible, arte más intenso |
| 7 — Sala del jefe | — | Boss fight (ver sección 7) | Clímax visual/sonoro |

*Ajustar cantidad de salas sobre la marcha según cómo avance la semana — mejor recortar a 5 salas bien pulidas que estirar a 7 flojas.*

---

## 7. Jefe final — Ojo flotante con manos

**Reutilizado de otra jam** (asset/rig ya existente — ahorra tiempo de arte y animación).

**Fase 1 — Manos:**
- Ataca con las manos: agarre/golpe melee que el jugador esquiva o bloquea con escudo.
- Enseña el patrón de esquiva/bloqueo antes de sumar el elemento a distancia.

**Fase 2 — El Ojo:**
- El ojo mismo dispara un proyectil (rayo, orbe) que el jugador refleja con el escudo — mecánica ya introducida en Sala 3, aquí se usa contra el jefe.
- Las manos siguen atacando en paralelo para mantener presión.

**Fase 3 (si da el tiempo) — Enrage/clímax:**
- Combina ambos patrones con más velocidad o un patrón nuevo simple (ej. el ojo mira y "marca" el piso antes de un golpe de área).
- Si no da el tiempo, 2 fases son un boss fight completo y válido.

---

## 8. Scope y prioridades (semana de jam)

**Día 1-2:** Movimiento, cámara por sala, sistema de colisión/interacción básico, primer prototipo de espada y escudo.
**Día 3-4:** Salas 1-3 jugables con sus puzzles, primer enemigo básico.
**Día 5:** Salas 4-6, integrar ambientación progresiva (luz, partículas de polvo, audio).
**Día 6:** Jefe (fases 1 y 2), integrar rig reciclado.
**Día 7:** Pulido, audio final, build (Linux/Windows prioritario), testing, fase 3 del jefe SI hay tiempo.

**Qué cortar primero si falta tiempo (en este orden):**
1. Fase 3 del jefe (enrage).
2. Sala 6 (previa al jefe) — fusionar su puzzle con la sala 5.
3. Enemigos "de relleno" en salas que no los necesitan estructuralmente.
4. Pulido de arte ambiental en salas tempranas (dejar solo en las salas cercanas al jefe, donde más se nota el doom).

**Qué NO cortar (son el corazón del pitch):**
- La doble función del escudo (combate + puzzle).
- La progresión ambiental del doom sala por sala.
- El boss fight con al menos 2 fases.

---

## 9. Pendientes / decisiones abiertas

- [ ] Elegir Opción A o B de historia (o una variante propia).
- [ ] Título del juego.
- [ ] Definir si hay diálogo/texto o todo es ambiental (sin NPCs que hablen, por scope).
- [ ] Confirmar cantidad final de salas según avance real de la semana.
- [ ] Diseño concreto de cada puzzle de sala (esto es la siguiente sesión de trabajo).
