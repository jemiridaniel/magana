# ASR benchmark

NCAIR1 Whisper Small models, transformers fp32 on an Apple M2 Pro CPU (16 GB), FLEURS test clips 1-10 per language (read speech; English is en_us), white noise added at 10 and 5 dB SNR.

Runaway clips: the model repeated itself, giving more than twice as many words as the reference.

| Language / condition | Clips | WER | WER without tone marks | Runaway clips | Median s (audio s) |
|---|---|---|---|---|---|
| ha/clean | 10 | 0.291 | 0.291 | 0 | 3.4 (14.16) |
| ha/snr10 | 10 | 0.563 | 0.563 | 0 | 3.34 (14.16) |
| ha/snr5 | 10 | 0.665 | 0.665 | 0 | 3.39 (14.16) |
| yo/clean | 10 | 0.566 | 0.358 | 0 | 9.32 (15.09) |
| yo/snr10 | 10 | 0.701 | 0.474 | 0 | 10.3 (15.09) |
| yo/snr5 | 10 | 1.028 | 0.741 | 0 | 8.3 (15.09) |
| ig/clean | 10 | 0.413 | 0.346 | 0 | 6.8 (14.52) |
| ig/snr10 | 10 | 1.145 | 1.112 | 1 | 8.53 (14.52) |
| ig/snr5 | 10 | 1.476 | 1.457 | 2 | 6.64 (14.52) |
| en/clean | 10 | 0.085 | 0.085 | 0 | 1.74 (10.23) |
| en/snr10 | 10 | 0.232 | 0.232 | 0 | 1.87 (10.23) |
| en/snr5 | 10 | 0.284 | 0.284 | 0 | 1.65 (10.23) |
