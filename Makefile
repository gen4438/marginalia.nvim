.PHONY: test lint format install-hooks bump-patch bump-minor bump-major

test:
	nvim --headless --noplugin -u tests/minimal_init.lua -c "lua require('plenary.test_harness').test_directory('tests/marginalia', { minimal_init = 'tests/minimal_init.lua' })"

lint:
	luacheck lua/ tests/

format:
	stylua lua/ tests/

install-hooks:
	pre-commit install

bump-patch:
	@LATEST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	VERSION=$${LATEST_TAG#v}; \
	MAJOR=$$(echo $$VERSION | cut -d. -f1); \
	MINOR=$$(echo $$VERSION | cut -d. -f2); \
	PATCH=$$(echo $$VERSION | cut -d. -f3); \
	NEW_PATCH=$$((PATCH + 1)); \
	NEW_TAG="v$$MAJOR.$$MINOR.$$NEW_PATCH"; \
	echo "Bumping patch version: $$LATEST_TAG -> $$NEW_TAG"; \
	sed -i 's/M.version = "[^"]*"/M.version = "'$$MAJOR.$$MINOR.$$NEW_PATCH'"/' lua/marginalia/init.lua; \
	git add lua/marginalia/init.lua; \
	git commit -m "chore: release $$NEW_TAG" || echo "Nothing to commit"; \
	git tag -a $$NEW_TAG -m "Release $$NEW_TAG"; \
	echo "Don't forget to push the commit and tag: git push origin main && git push origin $$NEW_TAG"

bump-minor:
	@LATEST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	VERSION=$${LATEST_TAG#v}; \
	MAJOR=$$(echo $$VERSION | cut -d. -f1); \
	MINOR=$$(echo $$VERSION | cut -d. -f2); \
	NEW_MINOR=$$((MINOR + 1)); \
	NEW_TAG="v$$MAJOR.$$NEW_MINOR.0"; \
	echo "Bumping minor version: $$LATEST_TAG -> $$NEW_TAG"; \
	sed -i 's/M.version = "[^"]*"/M.version = "'$$MAJOR.$$NEW_MINOR.0'"/' lua/marginalia/init.lua; \
	git add lua/marginalia/init.lua; \
	git commit -m "chore: release $$NEW_TAG" || echo "Nothing to commit"; \
	git tag -a $$NEW_TAG -m "Release $$NEW_TAG"; \
	echo "Don't forget to push the commit and tag: git push origin main && git push origin $$NEW_TAG"

bump-major:
	@LATEST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	VERSION=$${LATEST_TAG#v}; \
	MAJOR=$$(echo $$VERSION | cut -d. -f1); \
	NEW_MAJOR=$$((MAJOR + 1)); \
	NEW_TAG="v$$NEW_MAJOR.0.0"; \
	echo "Bumping major version: $$LATEST_TAG -> $$NEW_TAG"; \
	sed -i 's/M.version = "[^"]*"/M.version = "'$$NEW_MAJOR.0.0'"/' lua/marginalia/init.lua; \
	git add lua/marginalia/init.lua; \
	git commit -m "chore: release $$NEW_TAG" || echo "Nothing to commit"; \
	git tag -a $$NEW_TAG -m "Release $$NEW_TAG"; \
	echo "Don't forget to push the commit and tag: git push origin main && git push origin $$NEW_TAG"
