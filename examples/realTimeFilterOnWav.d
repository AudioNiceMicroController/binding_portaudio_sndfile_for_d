import libsndfile.libsndfilebind;
import portaudio.portaudiobind;
import std.string : fromStringz, toStringz;
import std.stdio;
import std.format;
import core.stdc.stdlib : exit;  // Ajoutez cette ligne

int ii=0;

// Constante pour la taille du buffer
enum BUFFER_SIZE = 512;

struct Data{
    SNDFILE* snd;
    SF_INFO info;
    FilterState* filter; // Ajoute ce champ
    double[BUFFER_SIZE*2]bufferStereo; // Buffer pour les canaux stéréo
}


//--------------------------------------------------------
// Filtre IIR Direct Form 1
struct CanalRealTimeProcessing{
    double[] x;  // mémoire des entrées passées
    double[] y;  // mémoire des sorties passées
}
struct FilterState {
    double[] a;  // coefficients feedback (dénominateur), a[0] = 1.0
    double[] b;  // coefficients feedforward (numérateur)
    CanalRealTimeProcessing gauche; // Canal gauche
    CanalRealTimeProcessing droit;   // Canal droit
    size_t ordre; // ordre du filtre

    this(double[] bCoeffs, double[] aCoeffs) {
        b = bCoeffs.dup;
        a = aCoeffs.dup;
        if (a.length > 0 && a[0] != 1.0)
            throw new Exception("Le premier coefficient de a doit être 1.0");
        assert(b.length > 0, "Le filtre doit avoir au moins un coefficient b");
        assert(a.length > 0, "Le filtre doit avoir au moins un coefficient a");
        assert(b.length == a.length, "Les coefficients b et a doivent avoir la même longueur");
        ordre = a.length - 1;
        gauche = CanalRealTimeProcessing();// réinitialisation des canaux
        droit = CanalRealTimeProcessing();
        gauche.x = new double[a.length];
        gauche.y = new double[a.length];
        droit.x = new double[a.length];
        droit.y = new double[a.length];
        gauche.x[]=0; // Initialisation des entrées passées à zéro
        gauche.y[]=0; // Initialisation des sorties passées à zéro
        droit.x[]=0; // Initialisation des entrées passées à zéro
        droit.y[]=0; // Initialisation des sorties passées à zéro
    }
}
// Filtre global
FilterState globalFilter;


float iirRealTimeProcessing(float input, FilterState *fs, CanalRealTimeProcessing *c) {
    auto N = fs.b.length - 1;
    for (auto n = N; n >= 1; n--) {
        c.x[n] = c.x[n - 1];
    }
    c.x[0] = input; // Initialisation de l'entrée actuelle
    double y0 = 0.0; // Initialisation de la sortie actuelle
    for (auto n = 0; n <= N; n++) {
        y0 += fs.b[n] * c.x[n];
    }
    for (auto n = 1; n <= N; n++) {
        y0 -= fs.a[n] * c.y[n];
    }
    // décaler les sorties
    for (auto n = N; n >= 1; n--) {
        c.y[n] = c.y[n - 1];
    }
    
    c.y[0] = y0; // Stockage de la sortie actuelle
    return cast(float)y0; // Retourne la sortie actuelle
}

extern(C) @trusted
PaStreamCallbackResult audioCallback(
                            const(void)* input, 
                            void* output,
                            ulong frameCount,
                            const(PaStreamCallbackTimeInfo)* timeInfo,
                            PaStreamCallbackFlags statusFlags,
                            void* userData) {
    auto data = cast(Data*)userData;

    // Nombre total d'échantillons à lire : frames × canaux
    size_t totalSamples = frameCount * data.info.channels;
    
    // Lire les échantillons audio
    auto out_ = cast(float*)output;
    // cast en slice D : // Pas de copie // Pas d’allocation // Opération O(1)
    float[] outSlice = out_[0 .. totalSamples];

    sf_count_t samplesRead = sf_read_float(data.snd, out_, totalSamples);
    
    // Appliquer le filtre seulement si on a lu des échantillons
    if (samplesRead > 0) {
        for (size_t i = 0; i < samplesRead; i+=2) {
            outSlice[i] = iirRealTimeProcessing(outSlice[i], data.filter, &data.filter.gauche);
            outSlice[i+1] = iirRealTimeProcessing(outSlice[i+1], data.filter, &data.filter.droit);
        }   
    }   
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

Data data;
PaStream* stream = null;

void main() {

    PaError err;
    PaDeviceInfo *deviceInfo;
    string nf= "/Users/uio/Music/_.wav";
    int defaultDevice;
    uint format, pcm;
    const(PaStreamInfo)* streamInfo;


    // Initialiser le filtre
double[] b = [0.066605780250, 0.066605780250];
double[] a = [1.000000000000, -0.866788439500]; 
    globalFilter = FilterState(b, a);
    writefln("globalFilter.a[0] = %f", globalFilter.a[0]);
    data.filter = &globalFilter; // Associer le filtre à la structure Data
    data.snd =ouvreSF(nf.toStringz(), &data.info);


    lireInfosDuWav(&data.info);

    initPortaudio();

    ouvreLeStreamParDefaut();

    ditLesInfosDuStream(stream);
    commenceLeStream(stream);

    writeln("Lecture en cours...");
    while (Pa_IsStreamActive(stream) == 1) {
        Pa_Sleep(100);
    }
    writeln("Lecture terminée.");

    fermerTout(stream, data.snd);
}
/*

dub run --config=realTimeFilterOnWav

*/

void initPortaudio() {
    PaError err = Pa_Initialize();
    if (err != PaError.paNoError) {
        writeln("Erreur d'initialisation de PortAudio : ", fromStringz(Pa_GetErrorText(err)));
        exit(1);
    }
}

void ditLesInfosDuStream(PaStream* stream) {
    const(PaStreamInfo)* info = Pa_GetStreamInfo(stream);
    if (info !is null) {
        writeln("\nPa : Informations du flux :");
        writeln("Version de la structure : ", info.structVersion);
        writeln("Latence d'entrée : ", info.inputLatency);
        writeln("Latence de sortie : ", info.outputLatency);
        writeln("Taux d'échantillonnage : ", info.sampleRate);
    } else {
        writeln("Aucune information disponible pour le flux.");
    }
}
void commenceLeStream(PaStream* stream) {
    PaError err = Pa_StartStream(stream);
    if (err != PaError.paNoError) {
        writeln("Erreur de démarrage du flux : ", fromStringz(Pa_GetErrorText(err)));
        exit(1);
    }
}
void stopLeStream(PaStream* stream) {
    PaError err = Pa_StopStream(stream);
    if (err != PaError.paNoError) {
        writeln("Erreur d'arrêt du flux : ", fromStringz(Pa_GetErrorText(err)));
        exit(1);
    }
}

void fermerTout(PaStream* stream, SNDFILE* snd) {
    stopLeStream(stream);
    if (stream !is null) {
        Pa_CloseStream(stream);
    }
    if (snd !is null) {
        sf_close(snd);
    }
    Pa_Terminate();
}
void lireInfosDuWav(SF_INFO* info) {
    writeln("\nSND : Informations du fichier WAV :");
    int pcm = info.format & SF_FORMAT_SUBMASK;
    if (pcm == SF_FORMAT_PCM_16) {
        writeln("Format PCM 16 bits");
    } else if (pcm == SF_FORMAT_PCM_24) {
        writeln("Format PCM 24 bits");
    } else if (pcm == SF_FORMAT_PCM_32) {
        writeln("Format PCM 32 bits");
    } else if (pcm == SF_FORMAT_FLOAT) {
        writeln("Format Float");
    } else if (pcm == SF_FORMAT_DOUBLE) {
        writeln("Format Double");
    } else {
        writeln("Format inconnu : ", pcm);
    }
    if (info.channels == 1) {
        writeln("Mono");
    } else if (info.channels == 2) {
        writeln("Stéréo");
    } else {
        writeln("Nombre de canaux : ", info.channels);
    }
    if (info.samplerate == 0) {
        writeln("Taux d'échantillonnage inconnu");
    } else {
        writeln("Taux d'échantillonnage : ", info.samplerate);
    }
    if (info.frames == 0) {
        writeln("Nombre d'échantillons inconnu");
    } else {
        writeln("Nombre d'échantillons : ", info.frames);
    }
    if (info.format == 0) {
        writeln("Format inconnu");
    }
}
SNDFILE *ouvreSF(const(char)* filename, SF_INFO* info) {
    SNDFILE *snd = sf_open(filename, SFM_READ, info);
    if (snd is null) {
        writeln("ouvreSF: Erreur d'ouverture du fichier WAV : ", fromStringz(sf_strerror(null)));
    }
    return snd;
}

void ouvreLeStreamParDefaut() {
    PaError err = Pa_OpenDefaultStream(
        &stream,
        0, // pas d'entrée
        data.info.channels,
        paFloat32, // format float
        data.info.samplerate,
        BUFFER_SIZE, // frames par buffer
        &audioCallback,
        &data
    );
    if (err != PaError.paNoError) {
        writeln("Erreur d'ouverture du flux audio : ", fromStringz(Pa_GetErrorText(err)));
        sf_close(data.snd);
        Pa_Terminate();
        exit(1);
    }
}
