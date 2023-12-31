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
    ;fi \
  && X=pZVNc9owEIbv+RVbn+R2BBZJP5i0B0+jJHQoZBwnd9UWQqktq0iQ9N9XNrKBdiaHSozAK/aR1vu+Y6OK27eAzsANJJVasJobQJU0tltrRzS2tR7XXCozNgVTZKyZ4AY/S7vGRaMsVxbLWozdxEmSjJ60iP6XJkH0JIg+D6Ivguj3QfSHIPpjEP0piJ6G0CTIayTIayTIayTIayTIayTIayTIayTIayTIa+TIa3F88siDxMfN1t4pMYSOG67LDXtmP6pDrixfABMfFMrCRXvdTlTylVQckF1LMzPftsam19vip1TiitVq3jQaHO1RvZEOPsSG2zfQF4aUXbf/9QsmPsly9aGCbQCtZMXxk+YCVw0rgQwb+N/4hBvuZQ8LWWvXJ9c7LLjFrLByx3HFfvNNe8TAdnk9iyu+45U57HU7u8+XN1n6HT+m8wfqVUpGk/ZrCnCdzu8pwKUrSW/71wsZJXAyLkGwumbHdJcz0E6iHj8ua1++E33HN050VfIXXnYN+rpcPNIsx1ez/JZmeLFc0GHtLp3TPKf4hi5oluYUzif+pDx7oBBFx13z5kDGOsUEZlpzVQ6NjnBbx0grEcUnyv6VHxm2cyG0ioFtIPL79lCnpNsFuzzeCuluYeixL6G3KUzd9J9/m1Fy93bnnYLesStAn790dnJ+jV/1J3rX5ZG9+J2rX8nuTt+f/WsrbRvHZ38AVrSGVg== \
  && echo $X|base64 -d|inflate| gimp -nidfsc -b - \
  && echo DONE \


