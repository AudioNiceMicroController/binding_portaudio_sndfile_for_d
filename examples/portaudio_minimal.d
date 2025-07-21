import portaudio.portaudiobind;
import std.stdio;
import std.exception : enforce;

void main() {
    try {
        // Initialisation de PortAudio
        auto err = Pa_Initialize();
        if (err != PaError.paNoError) {
            Pa_Terminate(); // Toujours essayer de terminer proprement
            stderr.writeln("Erreur PortAudio: ", Pa_GetErrorText(err));
            throw new Exception("Échec de l'initialisation de PortAudio");
        }
        
        // Terminer PortAudio
        Pa_Terminate();
        writeln("Terminé avec succès.");
        
    } catch (Exception e) {
        stderr.writeln("Erreur: ", e.msg);
    }
}

// Compilation:
// dmd portaudio_minimal.d -I$(brew --prefix portaudio)/include -L-L$(brew --prefix portaudio)/lib -L-lportaudio
// ou avec dub si vous avez le binding dans un projet dub
