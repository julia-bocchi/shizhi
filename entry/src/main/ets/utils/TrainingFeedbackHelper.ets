import audio from '@ohos.multimedia.audio';
import vibrator from '@ohos.vibrator';

export interface TrainingFeedbackResult {
  soundPlayed: boolean;
  vibrationPlayed: boolean;
}

export const FEEDBACK_STYLE_STANDARD: string = 'standard';
export const FEEDBACK_STYLE_ALARM: string = 'alarm';

const REMINDER_SAMPLE_RATE: number = 44100;
const REMINDER_BURST_COUNT: number = 4;
const REMINDER_BURST_DURATION_MS: number = 300;
const REMINDER_BURST_GAP_MS: number = 150;
const REMINDER_DURATION_MS: number = REMINDER_BURST_COUNT * REMINDER_BURST_DURATION_MS + (REMINDER_BURST_COUNT - 1) * REMINDER_BURST_GAP_MS;
const REMINDER_PRIMARY_FREQUENCY_HZ: number = 920;
const REMINDER_SECONDARY_FREQUENCY_HZ: number = 660;
const REMINDER_VIBRATION_DURATION_MS: number = 900;
const FEEDBACK_REPEAT_INTERVAL_MS: number = 320;
const FEEDBACK_STANDARD_CYCLE_COUNT: number = 1;
const FEEDBACK_ALARM_CYCLE_COUNT: number = 2;

function wait(durationMs: number): Promise<void> {
  return new Promise((resolve: () => void) => {
    setTimeout((): void => {
      resolve();
    }, durationMs);
  });
}

function fillRendererBuffer(target: ArrayBuffer, source: ArrayBuffer, sourceOffset: number): number {
  let targetView: Uint8Array = new Uint8Array(target);
  let sourceView: Uint8Array = new Uint8Array(source);
  let remainingLength: number = sourceView.length - sourceOffset;
  let writeLength: number = remainingLength > 0 ? Math.min(targetView.length, remainingLength) : 0;

  for (let index = 0; index < writeLength; index++) {
    targetView[index] = sourceView[sourceOffset + index];
  }

  for (let index = writeLength; index < targetView.length; index++) {
    targetView[index] = 0;
  }

  return sourceOffset + writeLength;
}

function createReminderToneBuffer(): ArrayBuffer {
  let sampleCount: number = Math.floor(REMINDER_SAMPLE_RATE * REMINDER_DURATION_MS / 1000);
  let buffer: ArrayBuffer = new ArrayBuffer(sampleCount * 2);
  let samples: Int16Array = new Int16Array(buffer);
  let cycleDurationMs: number = REMINDER_BURST_DURATION_MS + REMINDER_BURST_GAP_MS;

  for (let index = 0; index < sampleCount; index++) {
    let elapsedMs: number = index * 1000 / REMINDER_SAMPLE_RATE;
    let burstIndex: number = Math.floor(elapsedMs / cycleDurationMs);
    if (burstIndex >= REMINDER_BURST_COUNT) {
      samples[index] = 0;
      continue;
    }

    let burstElapsedMs: number = elapsedMs - burstIndex * cycleDurationMs;
    if (burstElapsedMs > REMINDER_BURST_DURATION_MS) {
      samples[index] = 0;
      continue;
    }

    let burstProgress: number = burstElapsedMs / REMINDER_BURST_DURATION_MS;
    let envelope: number = 1;
    if (burstProgress < 0.15) {
      envelope = burstProgress / 0.15;
    } else if (burstProgress > 0.82) {
      envelope = (1 - burstProgress) / 0.18;
    }

    let primaryAngle: number = 2 * Math.PI * REMINDER_PRIMARY_FREQUENCY_HZ * index / REMINDER_SAMPLE_RATE;
    let secondaryAngle: number = 2 * Math.PI * REMINDER_SECONDARY_FREQUENCY_HZ * index / REMINDER_SAMPLE_RATE;
    let amplitude: number = (Math.sin(primaryAngle) * 0.72 + Math.sin(secondaryAngle) * 0.28) * 0.36 * Math.max(0, envelope);
    samples[index] = Math.round(amplitude * 32767);
  }

  return buffer;
}

const REMINDER_TONE_BUFFER: ArrayBuffer = createReminderToneBuffer();

export async function playReminderSound(): Promise<boolean> {
  let renderer: audio.AudioRenderer | undefined = undefined;
  let writeCallback: audio.AudioRendererWriteDataCallback | undefined = undefined;

  try {
    let options: audio.AudioRendererOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_44100,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      rendererInfo: {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      }
    };

    renderer = await audio.createAudioRenderer(options);
    let writeOffset: number = 0;
    writeCallback = (data: ArrayBuffer): audio.AudioDataCallbackResult => {
      if (writeOffset >= REMINDER_TONE_BUFFER.byteLength) {
        return audio.AudioDataCallbackResult.INVALID;
      }
      writeOffset = fillRendererBuffer(data, REMINDER_TONE_BUFFER, writeOffset);
      return audio.AudioDataCallbackResult.VALID;
    };
    renderer.on('writeData', writeCallback);
    await renderer.start();
    await wait(REMINDER_DURATION_MS + 220);
    renderer.off('writeData', writeCallback);
    try {
      await renderer.stop();
    } catch (error) {
    }
    await renderer.release();
    return true;
  } catch (error) {
    if (renderer !== undefined) {
      try {
        if (writeCallback !== undefined) {
          renderer.off('writeData', writeCallback);
        }
        await renderer.release();
      } catch (releaseError) {
      }
    }
    return false;
  }
}

export async function playReminderVibration(): Promise<boolean> {
  try {
    let effect: vibrator.VibrateEffect = {
      type: 'time',
      duration: REMINDER_VIBRATION_DURATION_MS
    };
    let attribute: vibrator.VibrateAttribute = {
      usage: 'notification'
    };
    await vibrator.startVibration(effect, attribute);
    return true;
  } catch (error) {
    return false;
  }
}

export async function playTrainingFeedback(enableSound: boolean, enableVibration: boolean, feedbackStyle: string): Promise<TrainingFeedbackResult> {
  let soundPlayed: boolean = false;
  let vibrationPlayed: boolean = false;
  let cycleCount: number = feedbackStyle === FEEDBACK_STYLE_ALARM ? FEEDBACK_ALARM_CYCLE_COUNT : FEEDBACK_STANDARD_CYCLE_COUNT;

  for (let cycleIndex = 0; cycleIndex < cycleCount; cycleIndex++) {
    let soundTask: Promise<boolean> | undefined = undefined;
    let vibrationTask: Promise<boolean> | undefined = undefined;

    if (enableSound) {
      soundTask = playReminderSound();
    }

    if (enableVibration) {
      vibrationTask = playReminderVibration();
    }

    if (soundTask !== undefined) {
      soundPlayed = (await soundTask) || soundPlayed;
    }

    if (vibrationTask !== undefined) {
      vibrationPlayed = (await vibrationTask) || vibrationPlayed;
    }

    if (cycleIndex < cycleCount - 1) {
      await wait(FEEDBACK_REPEAT_INTERVAL_MS);
    }
  }

  return {
    soundPlayed: soundPlayed,
    vibrationPlayed: vibrationPlayed
  };
}
