SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
PAPER         =
BUILDDIR      = _build

PAPEROPT_a4     = -D latex_paper_size=a4
PAPEROPT_letter = -D latex_paper_size=letter
ALLSPHINXOPTS   = -d $(BUILDDIR)/doctrees -T -D language=en $(PAPEROPT_$(PAPER)) $(SPHINXOPTS) .

#---

references:
	curl -fsSL https://github.com/umarcor/umarcor/archive/refs/heads/main.tar.gz | \
	tar -xz --strip-components=1 umarcor-main/references/

#---

theme:
	mkdir _theme
	curl -fsSL https://codeload.github.com/buildthedocs/sphinx.theme/tar.gz/v1 | tar xzf - --strip-components=1 -C _theme

#---

%:
	$(SPHINXBUILD) -b $@ $(ALLSPHINXOPTS) $(BUILDDIR)/$@

