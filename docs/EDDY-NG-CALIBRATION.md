# Guía de calibración BTT Eddy con eddy-ng (flujo TAP)

Basado en la wiki oficial: https://github.com/vvuk/eddy-ng/wiki
Máquina: Kingroon KP3S Pro S1 — config espejo en `config/`.

> **eddy-ng NO es un firmware aparte**: es un patch sobre Klipper + un
> reflasheo del MCU del Eddy. Cambia el enfoque: homing "grueso" por sensor y
> un **TAP** físico (el nozzle toca la cama) justo antes de imprimir, que
> fija el Z offset exacto. Elimina la compensación por temperatura (drift)
> del flujo BTT stock.

---

## Estado actual del repo (commit 2940861) ✅

La migración a eddy-ng YA está hecha y recalibrada (2026-09-15):

- `btteddy-ng.cfg` activo (`[probe_eddy_ng btt_eddy]`, offsets -20/-7).
- Calibración **v5 guardada** en `SAVE_CONFIG`: dos drive currents
  (`16` homing, `17` tap) + `tap_adjust_z: -0.02`.
- `homing_override` de Z con `PROBE_EDDY_NG_PROBE_STATIC HOME_Z=1`.
- `START_PRINT`: `PROBE_EDDY_NG_TAP` (centro) + `BED_MESH_CALIBRATE METHOD=rapid_scan`.
- `END_PRINT`: `PROBE_EDDY_NG_SET_TAP_OFFSET VALUE=0` + `BED_MESH_CLEAR`.
- Los macros BTT stock (G28 override, SET_Z_FROM_PROBE, etc.) están
  comentados o fuera del include.

> ⚠️ Con `[update_manager] channel: dev`, cada update de Klipper por Moonraker
> pisa el patch. Si la config deja de cargar: `cd ~/eddy-ng && ./install.sh`
> y reflashear el Eddy.

---

## Recalibración tras remontar el sensor (procedimiento)

> ⚠️ La curva guardada se calibra con la altura ACTUAL del sensor.
> Si lo desmontás y lo volvés a montar a otra altura, la curva queda
> inválida: **no hagas homing Z ni TAP hasta recalibrar** (riesgo de que el
> nozzle siga bajando contra la cama).
>
> Última ejecución completa: 2026-09-15 — SETUP OK, homing DC 16, tap DC 17,
> tap_adjust_z -0.02, mesh 6x6 bicubic guardado.

### 1. Montar el sensor a la altura correcta (crítico)

- Lo que importa es la **bobina (PCB)**, no el plástico del case: es ella la
  que mide (inductor del LDC1612). La pared de plástico (aprox. 1.2 mm) queda
  POR DEBAJO de la bobina, entre ella y la cama — consume parte del hueco.
  **Distancia real crítica: bobina (parte de abajo del PCB) → punta del
  nozzle = 2.5–3.0 mm**, óptimo ~2.95 mm.
- **Si medís al plástico (lo fácil)**: el fondo del case está MÁS CERCA de la
  cama que la bobina, así que ves MENOS espacio. Con el nozzle en Z=0:
  `hueco case→cama = 2.95 − 1.2 ≈ 1.75 mm` (rango 1.3–1.8).
  A cualquier otra altura Z: `hueco = Z + 1.75`. Para derivar la altura real
  de la bobina desde una medición al plástico, SUMÁS el grosor de la pared:
  `2.95 = 1.75 + 1.2`. (Si tu case mide distinto de 1.2 mm — medilo con
  calibre — ajustá: `hueco = 2.95 − grosor_real`.)
- **Método de verificación por resta de gaps** (con el toolhead quieto a
  cualquier altura Z): `hueco case→cama − hueco nozzle→cama` debe dar
  **~1.75 mm** constante (`h − p`). Si tu caso da ~1.4–1.5, tu bobina está
  demasiado cerca del nozzle.
- Altura mal puesta → errores de amplitud en TAP o calibración que no encuentra
  rango. Verificar también que el offset XY (-20, -7) no cambió.

### 2. Calibración (con la cama tibia)

```
G28 X Y                    ; con espacio entre X e Y
M140 S60 / M190 S60        ; cama a 50-60 °C (encuentra valores que sirven en caliente)
G1 X105 Y105 F6000         ; toolhead al centro
PROBE_EDDY_NG_SETUP        ; interactivo: paper test cuando lo pida
```

- El paper test no necesita ser muy preciso ("bueno a secas" alcanza).
- SETUP prueba parámetros de homing y tap (puede sugerir drive currents
  distintos de 16 — aceptar lo que proponga).

**Si SETUP falla**: usar manual:
```
PROBE_EDDY_NG_TEST_DRIVE_CURRENT DRIVE_CURRENT=16|17|18   ; ver rango válido
PROBE_EDDY_NG_CALIBRATE DRIVE_CURRENT=#                   ; calibrar ese valor
```
Homíng ideal: válido ~0–15 mm. Tap: válido desde ~0.0x hasta ≥ 4 mm.
¿Rango corto en la punta baja → sensor 1 mm más arriba; corto en la alta → 1 mm más abajo.

### 3. Verificar ANTES de guardar (mano en el e-stop)

```
PROBE_EDDY_NG_PROBE_STATIC       ; altura razonable, no "-inf"
G28 Z                            ; PRIMER home Z: mirá la impresora, listo para cortar
G0 Z2
PROBE_EDDY_NG_PROBE_STATIC       ; debe dar ~2.0 ± 0.025
G0 Z1
PROBE_EDDY_NG_PROBE_STATIC       ; ~1.0, más preciso entre 1-3 mm
```

Si está muy desviado → recalibrar. Si da bien: `SAVE_CONFIG`
(sobrescribe la curva vieja v5).

### 4. TAP (z offset exacto)

```
PROBE_EDDY_NG_TAP                ; nozzle limpio (restos de fila arruinan el tap)
```

- Verificar `Z=0.0` con papel: buena fricción. Si no:
  `PROBE_EDDY_NG_SET_TAP_ADJUST_Z VALUE=±0.050` y re-TAP; al final, volcar el
  valor a `tap_adjust_z:` en la config.
- Mesh de verificación: `BED_MESH_CALIBRATE METHOD=rapid_scan` — la
  desviación en el punto del tap debe ser ~0 (±0.005).

---

## Troubleshooting rápido

| Síntoma | Causa / acción |
| --- | --- |
| `X and Y must be homed before setup` | Falta homing XY: corré `G28 X Y` (con espacios) antes del SETUP. |
| `Unknown command: ldc1612_ng_start_stop` | Firmware del Eddy sin eddy-ng → recompilar/reflashear. |
| `Unknown command: PROBE_EDDY_NG_TAP` | Patch no aplicado → `cd ~/eddy-ng && ./install.sh`. |
| Error `UNREADCONV1 ERR_ALE` en homing | Altura del sensor (paso 1) o drive current incorrecto. |
| Errores solo en TAP | Subir `tap_drive_current` y recalibrar ese valor. |
| `probe completed movement without triggering` | ¿El "cero" real está por debajo de -0.250? → recalibrar o bajar `tap_target_z`. |
| Tap detectado "too close to target Z" | Bajar `tap_target_z` (más recorrido de contacto). |
| Tap corta en el aire | `tap_threshold` muy bajo o filamento en el nozzle. |
| `EDDYng Already sampling` | Suele seguir a un homing/mesh abortado → `RESTART`. |

---

## Herramientas de diagnóstico (vale la pena instalarlas en el Pi)

```bash
~/klippy-env/bin/pip3 install plotly==5.24.1 scipy
```
Genera `/tmp/eddy-calibration.html` y `/tmp/tap.html` (gráficos interactivos
para afinar threshold y ver la detección del tap).