// ignore_for_file: avoid_print

import 'dart:async';

import 'package:rohd/rohd.dart';

// Define a set of legal directions for SPI interface, will
// be pass as parameter to Interface
enum SPIDirection { controllerOutput, peripheralOutput }

// Create an interface for Serial Peripheral Interface
class SPIInterface extends Interface<SPIDirection> {
  // include the getter to the function
  Logic get sck => port('sck'); // serial clock
  Logic get sdi => port('sdi'); // serial data in (mosi)
  Logic get sdo => port('sdo'); // serial data out (miso)
  Logic get cs => port('cs'); // chip select

  SPIInterface() {
    // Output from Controller, Input to Peripheral
    setPorts([
      Port('sck'),
      Port('sdi'),
      Port('cs'),
    ], [
      SPIDirection.controllerOutput
    ]);

    // Output from Peripheral, Input to Controller
    setPorts([
      Port('sdo'),
    ], [
      SPIDirection.peripheralOutput
    ]);
  }
}

class Controller extends Module {
  late final SPIInterface controller;
  late final Logic _reset;
  late final Logic _clk;
  late final Logic _sin;

  Controller(SPIInterface controller, Logic reset, Logic clk, Logic sin) {
    // set input port to private variable instead,
    // we don't want other class to access this
    _reset = addInput('reset', reset);
    _clk = addInput('clk', clk);
    _sin = addInput('sin', sin);

    // define a new interface, and connect it
    // to the interface passed in.
    this.controller = SPIInterface()
      ..connectIO(
        this,
        controller,
        inputTags: {SPIDirection.peripheralOutput}, // Add inputs
        outputTags: {SPIDirection.controllerOutput}, // Add outputs
      );

    controller.cs <= Const(1);
    controller.sck <= _clk;

    Sequential(controller.sck, [
      IfBlock([
        Iff(_reset, [
          controller.sdi < 0,
        ]),
        Else([
          controller.sdi < _sin,
        ]),
      ])
    ]);
  }
}

class Peripheral extends Module {
  Logic get sck => input('sck');
  Logic get sdi => input('sdi');
  Logic get cs => input('cs');

  Logic get sdo => output('sdo');
  Logic get sout => output('sout');

  late final SPIInterface shiftRegIntF;

  Peripheral(SPIInterface shiftRegIntF) : super(name: 'shift_register') {
    this.shiftRegIntF = SPIInterface()
      ..connectIO(
        this,
        shiftRegIntF,
        inputTags: {SPIDirection.controllerOutput},
        outputTags: {SPIDirection.peripheralOutput},
      );
    // _buildLogic();
    const regWidth = 8;
    final data = Logic(name: 'data', width: regWidth);
    final sout = addOutput('sout', width: 8);

    Sequential(sck, [
      If(cs, then: [
        data < [data.slice(regWidth - 2, 0), sdi].swizzle()
      ], orElse: [
        data < 0
      ])
    ]);

    sout <= data;
    sdo <= data.getRange(0, 1);
  }
}

class TestBench extends Module {
  Logic get sout => output('sout');

  final spiInterface = SPIInterface();
  final clk = SimpleClockGenerator(10).clk;

  TestBench(Logic reset, Logic sin) {
    reset = addInput('reset', reset);
    sin = addInput('sin', sin);

    final sout = addOutput('sout', width: 8);

    final ctrl = Controller(spiInterface, reset, clk, sin);
    final peripheral = Peripheral(spiInterface);
  }
}

void main() async {
  final testInterface = SPIInterface();
  testInterface.sck <= SimpleClockGenerator(10).clk;

  final peri = Peripheral(testInterface);
  await peri.build();

  testInterface.cs.inject(0);
  testInterface.sdi.inject(0);

  print(peri.generateSynth());

  void printFlop([String message = '']) {
    print('@t=${Simulator.time}:\t'
        ' input=${testInterface.sdi.value}, output '
        '=${peri.sout.value.toString(includeWidth: false)}\t$message');
  }

  Future<void> drive(LogicValue val) async {
    for (var i = 0; i < val.width; i++) {
      peri.cs.put(1);
      peri.sdi.put(val[i]);
      await peri.sck.nextPosedge;

      printFlop();
    }
  }

  Simulator.setMaxSimTime(100);
  unawaited(Simulator.run());

  WaveDumper(peri, outputPath: 'doc/tutorials/chapter_8/spi.vcd');

  await drive(LogicValue.ofString('01010101'));
}
