/// Copyright (C) 2022 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// signal_redriven_exception.dart
/// An exception that is thrown when a signal is
/// redriven multiple times.
///
/// 2022 November 9
/// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:rohd/rohd.dart';

/// Thrown to indicate a [Logic] signal is operated multiple times.
class SignalRedrivenException implements Exception {
  late final String _message;

  /// Receives signals that are driven multiple times in string and
  /// append to the output of exception message.
  ///
  /// Creates a [SignalRedrivenException] with an optional error [message].
  SignalRedrivenException(String signals,
      [String message = 'Sequential drove the same signal(s) multiple times: '])
      : _message = message + signals;

  @override
  String toString() => _message;
}
