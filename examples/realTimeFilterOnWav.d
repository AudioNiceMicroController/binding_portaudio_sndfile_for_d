import libsndfile.libsndfilebind;
import portaudio.portaudiobind;
import std.string : fromStringz, toStringz;
import std.stdio;
import std.format;

struct Data{
    SNDFILE* snd;
    SF_INFO info;
}
double filterFunction(double dataRaw) {
    enum int filterOrder = 4;
    double y = 0;

    // Taille fixe des tableaux
    enum int arraySize = filterOrder+1;
    double[arraySize] a;
    double[arraySize] b;

    // Variables statiques (mémorisent les valeurs d'appel en appel)
    static double[arraySize] yIntermediate = [0.0, 0.0, 0.0, 0.0];
    static double[arraySize] xIntermediate = [0.0, 0.0, 0.0, 0.0];

    // Coefficients du filtre
a[0]  = 3.8302186497047874e-01;
a[1]  =-1.4620987554218603e+00;   b[1]  = 2.0206902783207523e+00;
a[2]  = 2.1597895341517730e+00;   b[2]  =-1.8599927841593680e+00;
a[3]  =-1.4620987554218603e+00;   b[3]  = 8.2253745479395324e-01;
a[4]  = 3.8302186497047869e-01;   b[4]  =-1.4681025766237743e-01;

    // Décalage des buffers
    for (int m = filterOrder; m > 0; --m) {
        yIntermediate[m] = yIntermediate[m - 1];
        xIntermediate[m] = xIntermediate[m - 1];
    }

    // Stocker la nouvelle donnée
    xIntermediate[0] = dataRaw;

    // Calcul du filtre
    for (int m = 0; m <= filterOrder; ++m) {
        y += a[m] * xIntermediate[m];
        if (m > 0) {
            y += b[m] * yIntermediate[m];
        }
    }

    // Mise à jour des intermédiaires
    yIntermediate[0] = y;

    return y;
}


double applyFIR(double input) {
    // Coefficients du filtre (supposés constants)
    immutable double[] firCoeffs = [
        0.00041582027766520177, 0.00030434498470724577, 0.00017647185247592526,
        -1.1580594464363166e-05, -0.00030941792654728826, -0.0007695820906489929,
        -0.001444278610158534, -0.002381902653727287, -0.0036235665108961916,
        -0.005199837751778276, -0.007127891573214548, -0.009409262640575433,
        -0.012028351982778724, -0.014951804770509293, -0.018128827320351096,
        -0.021492459142100854, -0.024961761348070467, -0.02844482949605697,
        -0.03184249012927787, -0.03505249886205053, -0.03797402637934466,
        -0.04051219913825119, -0.04258245514905321, -0.04411448246292725,
        -0.04505552857866089, 0.9550995824803418, -0.04505552857866088,
        -0.04411448246292724, -0.04258245514905321, -0.04051219913825118,
        -0.037974026379344654, -0.03505249886205052, -0.03184249012927787,
        -0.028444829496056957, -0.024961761348070457, -0.02149245914210085,
        -0.018128827320351093, -0.014951804770509287, -0.01202835198277872,
        -0.009409262640575424, -0.007127891573214548, -0.005199837751778276,
        -0.0036235665108961894, -0.0023819026537272845, -0.001444278610158532,
        -0.0007695820906489919, -0.00030941792654728826, -1.1580594464363161e-05,
        0.00017647185247592515, 0.00030434498470724555, 0.00041582027766520177
    ];

    // Static buffer circulaire pour les derniers échantillons
    enum int N = firCoeffs.length;
    static double[N] buffer = 0;
    static int index = 0;

    buffer[index] = input;

    double result = 0;
    int bufIndex = index;

    // Calcul du filtre
    foreach (i, coeff; firCoeffs) {
        result += coeff * buffer[bufIndex];
        bufIndex = (bufIndex - 1 + N) % N;  // buffer circulaire
    }

    // Avancer l'index du buffer circulaire
    index = (index + 1) % N;

    return result;
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
    double d, e;
    for (size_t i = 0; i < totalSamples; ++i){
        d = cast(double) out_[i];        // Convertir l'entrée en double
        e = applyFIR(d);           //applyFIR filterFunction Filtrage en double
        out_[i] = cast(short) e;         // Cast du résultat en short
    }

    return PaStreamCallbackResult.paContinue;
}


void main() {

    ///////////////////////////////////////////// déclaration des variables
    Data data;
    PaStream* stream = null; // ✅ déclarée avant tout goto
    PaError err;
    PaDeviceInfo *deviceInfo;
    string nf= "/Users/uio/Music/small.wav";
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
        512, // frames par buffer
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
