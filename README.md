# chili-utility-module

KiCad 10 project for the **chilichip utility module**: a small add-on board for the [chilichip console](https://github.com/chili-chip/vgc-zero-hardware) with a gyroscope/accelerometer, a vibration motor and a real-time clock. Everything sits on one I²C bus, so the module needs only the console's three free GPIOs.

Status: **schematic drawn** (ERC clean apart from three expected warnings, listed below). PCB layout not started.

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

The schematic has three ERC warnings, all expected:

- **Two "Bidirectional and Power output"**: the IMU's SA0 and SDx pins are bidirectional and tied straight to GND (SA0 selects the I²C address; SDx/SCx are the unused auxiliary I²C master).
- **One "Open collector and Output"**: on INT, KiCad's symbol types the IMU's INT1 as a push-pull output. Firmware sets it to open-drain, so it can share the line with the RTC's open-drain ~INT.

## Still to decide before layout

- **J1 footprint:** castellated edge pads like the audio and buttons modules, or a header. The console also needs a matching footprint and a spot on the board.
- **M1 footprint:** depends on how the motor is mounted (wire leads to two pads, or stuck down with an FPC tail).
- **BT1 footprint:** KiCad has none for the MYOUNG holder, so it needs drawing from its datasheet.
- **IMU SDx/SCx tie-off:** I tied them to GND, which is what secondary pin summaries say ("connect to VDDIO or GND" when unused). Check this against ST's LSM6DS3TR-C datasheet (DocID030071) pin table.
- **Power budget:** the motor draws about 60–80 mA at 3 V while running, from the Pico's 3.3 V output (budget about 300 mA).

## Files

| Path | Contents |
|------|----------|
| `chili-utility-module.kicad_sch` | Schematic |
| `chili-utility-module.kicad_sym`, `sym-lib-table` | Project symbols: LSM6DS3TR-C, RV-3028-C7, DRV2605L, Motor_ERM. Copied from KiCad 10's library, with manufacturer, part number and LCSC fields added |
