// Prints, as JSON, what the promo recorder must play for a staged scene (see promo_scenarios.dart). Not shipped.
//
//   dart --packages=.dart_tool/package_config.json tools/promo_plan.dart combo 1      # scenario and seed
//   dart --packages=.dart_tool/package_config.json tools/promo_plan.dart daily 24     # a daily, by number...
//   dart --packages=.dart_tool/package_config.json tools/promo_plan.dart daily 2026-11-12 14   # ...or date; 14 moves
//
// Each move is {slot, row, col, piece, rows, cols, lines, points, score, combo, perfect, tray}: drop the tray piece
// of [slot] with its top-left cell on (row, col); the rest is what the real game answered (lib/game), with the tray
// after the move. `peak` is the index of the scene's big moment. Scenarios: high_score, combo, perfect, near_death.
import 'dart:convert';
import 'dart:io';

import 'package:block_daily/game/game.dart';

import 'promo_scenarios.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stdout.writeln('usage: promo_plan.dart <${scenarioNames.join('|')}> [seed]  |  daily <number|YYYY-MM-DD> [moves]');
    return;
  }
  if (args[0] == 'daily') {
    final number = int.tryParse(args[1]) ?? dailyNumberFor(DateTime.parse(args[1]));
    stdout.writeln(jsonEncode(planDaily(number, length: args.length > 2 ? int.parse(args[2]) : 12)));
    return;
  }
  stdout.writeln(jsonEncode(buildScenario(args[0], args.length > 1 ? int.parse(args[1]) : 1).toJson()));
}
