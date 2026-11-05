# chili-utility-module

KiCad 10 project for the **chilichip utility module**: a small add-on board for the [chilichip console](https://github.com/chili-chip/vgc-zero-hardware) with a gyroscope/accelerometer, a vibration motor and a real-time clock. Everything sits on one I²C bus, so the module needs only the console's three free GPIOs.

Status: **schematic drawn, all footprints assigned** (ERC clean apart from two expected warnings, listed below). PCB layout not started.

## Parts

| Ref | Function | Part | LCSC |
|-----|----------|------|------|
| U1 | Gyro + accelerometer | **ST LSM6DS3TR-C**, 6-axis IMU, LGA-14 2.5 × 3 mm | [C967633](https://www.lcsc.com/product-detail/C967633.html) |
| U2 | Real-time clock | **Micro Crystal RV-3028-C7**, crystal built in, 45 nA, SON-8 1.5 × 3.2 mm | [C3019759](https://www.lcsc.com/product-detail/C3019759.html) |
| U3 | Haptic driver | **TI DRV2605L**, I²C ERM/LRA driver with 123 built-in effects, VSSOP-10 | [C527464](https://www.lcsc.com/product-detail/C527464.html) |
| M1 | Vibration motor | **LEADER LCM1027A2445F**, coin ERM 10 × 2.7 mm, 3 V | [C2759984](https://www.lcsc.com/product-detail/Vibration-Motor_LEADER-LCM1027A2445F_C2759984.html) |
| BT1 | RTC backup | CR1220 holder **MYOUNG MY-1220-03-R** | [C964819](https://www.lcsc.com/product-detail/C964819.html) |
| C1–C4, C6 | Decoupling | 100 nF 0402, Samsung CL05B104KO5NNNC | C1525 |
| C5, C7 | Driver VDD / REG | 1 µF 0402, Samsung CL05A105KA5NQNC | C52923 |
| R1, R2 | I²C pull-ups | 4.7 kΩ 0402, UNI-ROYAL 0402WGF4701TCE | C25900 |
| R3, R4 | INT pull-up, EVI tie-down | 10 kΩ 0402, UNI-ROYAL 0402WGF1002TCE | C25744 |

Why these parts:
- **LSM6DS3TR-C:** active ST part at about $0.60–0.90, with mature drivers (ST's platform-independent C driver, Adafruit, NuttX).
- **RV-3028-C7:** no external crystal or load capacitors, ±1 ppm, and an automatic switchover to the backup cell.
- **DRV2605L:** plays haptic effects over I²C, so the motor needs no PWM pin or MOSFET. That matters because the console has no GPIO left for one.

Alternatives considered:
- **QST QMI8658A** IMU: fewer drivers and no KiCad symbol.
- **NXP PCF85063A** RTC: needs an external crystal and draws about 5× more current.
- **MOSFET + flyback diode** for the motor: needs a spare PWM GPIO.

## Connector J1 (to the console)

| Pin | Signal | Console | Notes |
|-----|--------|---------|-------|
| 1 | 3V3 | Pico 3V3 | |
| 2 | SDA | GP0 (I2C0 SDA) | 4.7 kΩ pull-up R1 on the module |
| 3 | SCL | GP1 (I2C0 SCL) | 4.7 kΩ pull-up R2 on the module |
| 4 | INT | GP2 | open-drain, shared by IMU INT1 and RTC ~INT; 10 kΩ pull-up R3 |
| 5 | GND | GND | |

I²C addresses: IMU **0x6A** (SA0 to GND), RTC **0x52**, haptic driver **0x5A**.

GP0/GP1 are also the RP2350's default UART0 pins, so with this module fitted, use USB serial for debug output.

## Firmware setup the hardware relies on

- **IMU:** set INT1 to open-drain (`CTRL3_C` bit `PP_OD = 1`) before enabling any interrupt, because it shares the INT line with the RTC.
- **RTC:**
  - Enable backup switchover in level-switching mode (`BSM = 11` in register 37h) and store it to EEPROM. Switchover is disabled when the chip ships.
  - Leave the trickle charger off (`TCE = 0`, the default): the CR1220 is not rechargeable.
  - CLKOUT outputs 32.768 kHz by default; turn it off to save current.
- **Haptic driver:** select ERM mode and the ERM effect library, then run auto-calibration once for the motor. EN is tied high, so put the driver in standby through the `MODE` register when idle.

## ERC

The schematic has two ERC warnings, both expected: **"Bidirectional and Power output"** on the IMU's SA0 and SDx pins, which are bidirectional and tied straight to GND (SA0 selects the I²C address; SDx/SCx are the unused auxiliary I²C master).

In the project's `LSM6DS3TR-C` symbol, INT1/INT2 are typed open-collector rather than KiCad's push-pull output, because this design always sets them to open-drain so they can share the INT line with the RTC.

## Still to decide before layout

- **Console side:** the console needs a matching footprint (SMD lands for the five castellations) and a spot on the board.
- **IMU SDx/SCx tie-off:** I tied them to GND, which is what secondary pin summaries say ("connect to VDDIO or GND" when unused). Check this against ST's LSM6DS3TR-C datasheet (DocID030071) pin table.
- **Power budget:** the motor draws about 60–80 mA at 3 V while running, from the Pico's 3.3 V output (budget about 300 mA).

## Footprints

| Ref | Footprint | Source |
|-----|-----------|--------|
| J1 | `Castellated_1x05_P2.54mm` | Same castellated pads as the audio and buttons modules: 1.0 mm drill, 2.4 × 1.6 mm, on the board edge |
| BT1 | `BatteryHolder_MYOUNG_MY-1220-03_CR1220` | MYOUNG drawing MY-CP-0210 and LCSC's EasyEDA footprint: two + tabs 3.90 × 4.18 mm at ±7.9 mm, round 7.0 mm − pad under the cell (no paste) |
| M1 | `Motor_ERM_D10mm_WireLeads` | LEADER LCM1027A2445F drawing: 10 mm body (stuck down with its adhesive tape), AWG 34 leads into two 0.6 mm plated holes, + (red) and − (blue). Hand-soldered after assembly |
| U1–U3, passives | KiCad standard library | |

## Files

| Path | Contents |
|------|----------|
| `chili-utility-module.kicad_sch` | Schematic |
| `chili-utility-module.kicad_sym`, `sym-lib-table` | Project symbols: LSM6DS3TR-C, RV-3028-C7, DRV2605L, Motor_ERM. Copied from KiCad 10's library, with manufacturer, part number and LCSC fields added |
| `chili-utility-module.pretty/`, `fp-lib-table` | Project footprints: J1 castellated 1×05, BT1 MYOUNG CR1220 holder, M1 coin motor |
