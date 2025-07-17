import portaudio.portaudiobind;
import std.stdio;
import std.exception : enforce;
import core.math : sin;
import std.math : PI;
import core.sys.posix.time : timespec, nanosleep;

enum SAMPLE_RATE = 44100;
enum FRAMES_PER_BUFFER = 64;
enum NB_CHANNELS = 1;
enum double TWO_PI = 2 * PI;

struct ToneData {
    float phase;
    float frequency;
}

extern(C) @trusted
PaStreamCallbackResult audioCallback(
        const(void)* input, 
        void* output,
        ulong frameCount,
        const(PaStreamCallbackTimeInfo)* timeInfo,
        PaStreamCallbackFlags statusFlags,
        void* userData) {
    ToneData* data = cast(ToneData*)userData;
    short* out_ = cast(short*)output; 
    float sample;

    for (ulong i = 0; i < frameCount; i++) {
        sample = sin(data.phase) * 32767.0f;
        *out_++ = cast(short)sample;

        data.phase += TWO_PI * data.frequency / SAMPLE_RATE;
        if (data.phase > TWO_PI) {
            data.phase -= TWO_PI;
        }
    }

    return PaStreamCallbackResult.paContinue;
}

struct Stream {
    private ToneData data;
    private PaStream* stream;

    this(float frequency) {
        data.phase = 0.0f;
        data.frequency = frequency;

        enforce(Pa_Initialize() == PaError.paNoError, "Failed to initialize PortAudio");

        auto err = Pa_OpenDefaultStream(
            &stream, 
            0, 
            NB_CHANNELS, 
            paInt16,
            SAMPLE_RATE, FRAMES_PER_BUFFER,
            &audioCallback, 
            &data);

        enforce(err == PaError.paNoError, "Failed to open stream");
    }

    void play(int durationMs) {
        auto err = Pa_StartStream(stream);
        enforce(err == PaError.paNoError, "Failed to start stream");

        timespec ts;
        ts.tv_sec = durationMs / 1000;
        ts.tv_nsec = (durationMs % 1000) * 1_000_000;
        nanosleep(&ts, null);

        err = Pa_StopStream(stream);
        enforce(err == PaError.paNoError, "Failed to stop stream");
    }

    void close() {
        auto err = Pa_CloseStream(stream);
        enforce(err == PaError.paNoError, "Failed to close stream");

        Pa_Terminate();
    }

    ~this() {
        close(); // s'exécute automatiquement à la destruction
    }
}

void main() {
    try {
        auto stream = Stream(440.0f); // 440 Hz
        writeln("Playing a 440 Hz sine wave...");
        stream.play(500); // 500 ms
        writeln("Finished.");
    } catch (Throwable e) {
        stderr.writeln("Erreur : ", e.msg);
    }
}
