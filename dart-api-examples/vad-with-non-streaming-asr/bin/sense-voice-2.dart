// Copyright (c)  2024  Xiaomi Corporation
//
// Different from ./sense-voice.dart, this file uses a CircularBuffer
import 'dart:io';

import 'package:args/args.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import './init.dart';

void main(List<String> arguments) async {
  await initSherpaOnnx();

  final parser = ArgParser()
    ..addOption('silero-vad', help: 'Path to silero_vad.onnx')
    ..addOption('model', help: 'Path to the SenseVoice model')
    ..addOption('tokens', help: 'Path to tokens.txt')
    ..addOption('language',
        help: 'auto, zh, en, ja, ko, yue, or leave it empty to use auto',
        defaultsTo: '')
    ..addOption('use-itn',
        help: 'true to use inverse text normalization', defaultsTo: 'false')
    ..addOption('input-wav', help: 'Path to input.wav to transcribe');

  final res = parser.parse(arguments);
  if (res['silero-vad'] == null ||
      res['model'] == null ||
      res['tokens'] == null ||
      res['input-wav'] == null) {
    print(parser.usage);
    exit(1);
  }

  // create VAD
  final sileroVad = res['silero-vad'] as String;

  final sileroVadConfig = sherpa_onnx.SileroVadModelConfig(
    model: sileroVad,
    minSilenceDuration: 0.25,
    minSpeechDuration: 0.5,
    maxSpeechDuration: 5.0,
  );

  final vadConfig = sherpa_onnx.VadModelConfig(
    sileroVad: sileroVadConfig,
    numThreads: 1,
    debug: true,
  );

  final vad = sherpa_onnx.VoiceActivityDetector(
      config: vadConfig, bufferSizeInSeconds: 10);

  // create SenseVoice
  final model = res['model'] as String;
  final tokens = res['tokens'] as String;
  final inputWav = res['input-wav'] as String;
  final language = res['language'] as String;
  final useItn = (res['use-itn'] as String).toLowerCase() == 'true';

  final senseVoice = sherpa_onnx.OfflineSenseVoiceModelConfig(
      model: model, language: language, useInverseTextNormalization: useItn);

  final modelConfig = sherpa_onnx.OfflineModelConfig(
    senseVoice: senseVoice,
    tokens: tokens,
    debug: true,
    numThreads: 1,
  );
  final config = sherpa_onnx.OfflineRecognizerConfig(model: modelConfig);
  final recognizer = sherpa_onnx.OfflineRecognizer(config);

  final waveData = sherpa_onnx.readWave(inputWav);
  if (waveData.sampleRate != 16000) {
    print('Only 16000 Hz is supported. Given: ${waveData.sampleRate}');
    exit(1);
  }

  final buffer = sherpa_onnx.CircularBuffer(capacity: 30 * 16000);
  buffer.push(waveData.samples);

  while (buffer.size > vadConfig.sileroVad.windowSize) {
    final samples =
        buffer.get(startIndex: buffer.head, n: vadConfig.sileroVad.windowSize);
    buffer.pop(vadConfig.sileroVad.windowSize);

    vad.acceptWaveform(samples);

    while (!vad.isEmpty()) {
      final samples = vad.front().samples;
      final startTime = vad.front().start.toDouble() / waveData.sampleRate;
      final endTime =
          startTime + samples.length.toDouble() / waveData.sampleRate;

      final stream = recognizer.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: waveData.sampleRate);
      recognizer.decode(stream);

      final result = recognizer.getResult(stream);
      stream.free();
      print(
          '${startTime.toStringAsPrecision(5)} -- ${endTime.toStringAsPrecision(5)} : ${result.text}');

      vad.pop();
    }
  }

  vad.flush();

  while (!vad.isEmpty()) {
    final samples = vad.front().samples;
    final startTime = vad.front().start.toDouble() / waveData.sampleRate;
    final endTime = startTime + samples.length.toDouble() / waveData.sampleRate;

    final stream = recognizer.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: waveData.sampleRate);
    recognizer.decode(stream);

    final result = recognizer.getResult(stream);
    stream.free();
    print(
        '${startTime.toStringAsPrecision(5)} -- ${endTime.toStringAsPrecision(5)} : ${result.text}');

    vad.pop();
  }

  buffer.free();
  vad.free();

  recognizer.free();
}
