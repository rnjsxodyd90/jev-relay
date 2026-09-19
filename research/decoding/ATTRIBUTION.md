# Vocabulary attribution

The word decoders use the first 8,192 unique lowercased word entries (filtered for Dutch alphabetic tokens) from:
https://github.com/oprogramador/most-common-words-by-language/blob/master/src/resources/dutch.txt

That repository identifies its Dutch source as hermitdave/FrequencyWords:
https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2016/nl/nl_50k.txt

FrequencyWords identifies its content license as CC BY-SA 4.0:
https://github.com/hermitdave/FrequencyWords
https://creativecommons.org/licenses/by-sa/4.0/

Changes: filtered tokens, lowercased, removed duplicates, retained 8,192 entries; a 1,024-entry initial subset is also included. The derived vocabulary files are shared under CC BY-SA 4.0. This is a frequency list, not a translation phrasebook. No held-out target sentence was supplied to a decoder.
