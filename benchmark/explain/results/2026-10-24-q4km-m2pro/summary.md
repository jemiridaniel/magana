# Explanation benchmark: llamacpp NCAIR1/N-ATLaS

N-ATLaS base model, QuantFactory Q4_K_M GGUF (sha256 71de156e...), llama.cpp llama-server on an Apple M2 Pro (Metal, 16 GB), context 8192, temperature 0.1, repeat penalty 1.12, the app's prompts. Team-written test pages only.

| Language | Pages | Answered | Rejected by guard | Number-change rate | Median s |
|---|---|---|---|---|---|
| en | 10 | 10 | 3 | 0.3 | 4.23 |
| ha | 10 | 10 | 4 | 0.4 | 6.18 |
| yo | 10 | 10 | 4 | 0.4 | 5.965 |
| ig | 10 | 10 | 3 | 0.3 | 6.46 |

Unreviewed: fluency and faithfulness need native-speaker ratings (ratings_<lang>.csv).
