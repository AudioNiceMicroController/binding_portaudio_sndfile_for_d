import libsndfile.libsndfilebind;
import portaudio.portaudiobind;
import std.string : fromStringz, toStringz;
import std.stdio;
import std.format;

struct Data{
    SNDFILE* snd;
    SF_INFO info;
}

extern(C) @trusted
PaStreamCallbackResult audioCallback(const(void)* input, void* output,
                                     ulong frameCount,
                                     const(PaStreamCallbackTimeInfo)* timeInfo,
                                     PaStreamCallbackFlags statusFlags,
                                     void* userData) {
    auto data = cast(Data*)userData;
    auto out_ = cast(short*)output;

    // Nombre total d'échantillons à lire : frames × canaux
    size_t totalSamples = frameCount * data.info.channels;

    // Lire les échantillons audio
    sf_count_t samplesRead = sf_read_short(data.snd, out_, totalSamples);

    if (samplesRead < totalSamples) {
        // Fin du fichier
        // Zéro-padding pour finir proprement
        for (size_t i = samplesRead; i < totalSamples; ++i) {
            out_[i] = 0;
        }
        return PaStreamCallbackResult.paComplete;
    }

    return PaStreamCallbackResult.paContinue;
}


void main() {

    ///////////////////////////////////////////// déclaration des variables
    Data data;
    PaStream* stream = null; // ✅ déclarée avant tout goto
    PaError err;
    PaDeviceInfo *deviceInfo;
    string nf= "/Users/uio/Music/_.wav";
    int defaultDevice;
    uint format, pcm;

    ///////////////////////////////////////////// ouverture du wav en lecture
    data.snd = sf_open(nf.toStringz(), SFM_READ, &data.info);
    // const(char)* nf = "/Users/uio/Music/_.wav";
    // data.snd = sf_open(nf, SFM_READ, &data.info);
    if (data.snd == null) {
        writeln("Erreur d'ouverture du fichier WAV : ", fromStringz(sf_strerror(null)));
        goto fin1;
    }

    ///////////////////////////////////////////// lire les infos du wav
    format = data.info.format & SF_FORMAT.TYPEMASK;
    pcm = data.info.format & SF_FORMAT.SUBMASK;
    if (format == SF_FORMAT.WAV){
        writeln(" - Format : Wav");
    }    
    if (pcm == SF_FORMAT.PCM_16){
        writeln(" - PCM 16-bit");
    }
    writeln(" - Sample rate : ", data.info.samplerate); // 44100, 48000...
    writeln(" - # canal : ", data.info.channels); // 1 (mono), 2 (stéréo)...


    ///////////////////////////////////////////// initialisation de portaudio
    err = Pa_Initialize();
    if (err != PaError.paNoError) { 
        writeln("Erreur : ", fromStringz(sf_strerror(null)));
        goto fin1;
    }

    ///////////////////////////////////////////// TEST des périph
    defaultDevice = Pa_GetDefaultOutputDevice();
    writeln("Pa_GetDefaultOutputDevice : ",defaultDevice);
    if (defaultDevice == PaError.paNoDevice) {
        writeln("Aucun périphérique de sortie audio par défaut n'est disponible.");
        goto fin1;
    }
    
    deviceInfo = Pa_GetDeviceInfo(defaultDevice);
    writeln("Périphérique par défaut : ", fromStringz((*deviceInfo).name));

    ///////////////////////////////////////////// ouverture du stream
    err = Pa_OpenDefaultStream(
        &stream,
        0, // pas d'entrée
        data.info.channels,
        paInt16,
        data.info.samplerate,
        256, // frames par buffer
        &audioCallback,
        &data
    );

    if (err != PaError.paNoError) {
        writeln("Erreur d'ouverture du flux audio : ", fromStringz(Pa_GetErrorText(err)));
        sf_close(data.snd);
        Pa_Terminate();
        goto fin2;
    }
    ///////////////////////////////////////////// start stream
    Pa_StartStream(stream);
    writeln("Lecture en cours...");

    // Boucle d'attente pendant la lecture
    while (Pa_IsStreamActive(stream) == 1) {
        Pa_Sleep(100);
    }
    writeln("Lecture terminée.");

fin4:
    if (stream !is null)
        Pa_StopStream(stream);
fin3:
    if (stream !is null)
        Pa_CloseStream(stream);
fin2:
    Pa_Terminate();
fin1:
    if (data.snd !is null)
        sf_close(data.snd);
}
