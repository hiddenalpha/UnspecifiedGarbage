#!/bin/sh
#
# Once used to batch process some PDFs. This is NOT functional. It is only here
# for reference purposes.
#

true \
  && pdftk \
      A=scan.pdf \
      B=scan0001.pdf \
      shuffle A Bend-1 \
      output all-pages.pdf \
  && pdftk \
    all-pages.pdf \
    cat 1 3 5 7 8 9 11 12 13 14 15 16 17 18 19 20 21 22 23 24 \
    output pages-with-content.pdf \
  && if test ! -d pages-with-content-img; then true \
    && mkdir -p pages-with-content-img \
    && pdfimages -all  pages-with-content.pdf  pages-with-content-img/img \
    ;fi; true \
  && X=pZZNc9owEIbv+RVbn+RmBBZp0zLpxdM4CR0KGeLkrtiLUGrLLhIk/feVjS2HTCeHSoyAtfdZ7cc7BlKg+QjkBOwiUqkFL1EDKaQ27bVmBWNT1uMSpdJjnXHFxjUXqOmzNBuaVcqgMlSWYmw3jaJo9FSL4H9p5kVPvOgzL/qTF/3Ziz73or940V+96KkPzby0xry0xry0xry0xry0xry0xry0xry0xry0xl5pLQyPHnkQdXa1M7dKONNy7nu+5c/8sRh8Zf4ClHVGpgxM2jvNJjmupUIgZiP1TP/YaRNf7bJfUolLXqp5VdVg8T7QGsi3xgYbJQTyiEKqrkii0XyAPk2izKZ17B/VXR3Oz+ZLMr4FspYF0qcaBS0qngNzIbrP8A3pqjvgQpa17ZztJhVoKM+M3CMt+B/cNoe8olvPnqYF7rHQQ7Sb2V26vF7FP+lDPL9P3OSi0aR5mwJcxfO7BODCJlbvhh8dNorgaF2A4GXJjyO0Xi6CHd4Q4jjBQylWEnvcWkmoHF8wb9v1fbl4SFYpvZylN8mKLpaLxF27jedJmib0OlkkqzhN4GzSnZau7hMIguMeduIh2mztoCmva1S5a3xAm0xGtRLB0L3aepq3RKD53prQzBBMBUEXecDa6dpI1HpiM1xbiOt5l0YvZZja3b3+1ZQc7X8AbKfa331HteS01R/rcgmd4t9h2mMPR/7eSdPY4clfwj6IxA== \
  && echo $X|base64 -d|inflate| gimp -nidfsc -b - \
  && echo DONE \


