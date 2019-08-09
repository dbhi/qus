#!/usr/bin/env sh

cd $(dirname "$0")

cp _index.Rmd index.Rmd

for part in context images tests dev faq refs; do
  printf "\n\n" >> index.Rmd
  cat _"$part".Rmd >> index.Rmd
done

cd ..

docker run --rm -v /$(pwd)://src -e LANG=en-GB rmdi Rscript -e "rmarkdown::render('index.Rmd', 'distill::distill_article')"
