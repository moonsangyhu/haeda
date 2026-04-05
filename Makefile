# Haeda Slice Automation
# Usage:
#   make slice-auto                         # auto-detect + run next slice
#   make slice-auto SLICE=slice-07          # run specific slice
#   make slice-auto SLICE=slice-07 WATCH=5  # custom heartbeat interval
#   make slice-auto SLICE=slice-07 WATCH=0  # disable heartbeat
#   make slice-status SLICE=slice-07        # show status
#   make slice-resume SLICE=slice-07        # resume interrupted run
#   make slice-clean SLICE=slice-07         # clean artifacts + worktrees
#   make slice-setup                        # install Agent SDK (optional)

PYTHON ?= python3
AUTOMATION = scripts/automation
SLICE ?=
WATCH ?= 10

.PHONY: slice-auto slice-status slice-resume slice-clean slice-setup

slice-auto:
ifdef SLICE
	$(PYTHON) $(AUTOMATION)/run_slice.py --slice $(SLICE) --watch-interval $(WATCH)
else
	$(PYTHON) $(AUTOMATION)/run_slice.py --auto --watch-interval $(WATCH)
endif

slice-status:
ifndef SLICE
	$(error SLICE is required. Usage: make slice-status SLICE=slice-07)
endif
	$(PYTHON) $(AUTOMATION)/run_slice.py --slice $(SLICE) --status

slice-resume:
ifndef SLICE
	$(error SLICE is required. Usage: make slice-resume SLICE=slice-07)
endif
	$(PYTHON) $(AUTOMATION)/run_slice.py --slice $(SLICE) --resume

slice-clean:
ifndef SLICE
	$(error SLICE is required. Usage: make slice-clean SLICE=slice-07)
endif
	$(PYTHON) $(AUTOMATION)/run_slice.py --slice $(SLICE) --clean

slice-setup:
	$(PYTHON) -m venv .venv-automation
	.venv-automation/bin/pip install claude-agent-sdk
	@echo "Setup complete. Use: PYTHON=.venv-automation/bin/python make slice-auto"

# --------------------------------------------------------------------------
# Refinement Pipeline
# Usage:
#   make refine REQUEST="fix badge spacing on completed cards"
#   make refine REQUEST_FILE=requests/badge-fix.md
#   make refine REQUEST_FILE=requests/badge-fix.md AUTO_PUSH=1
#   make refine-status RUN=refine-20260405-001
#   make refine-resume RUN=refine-20260405-001
#   make refine-clean RUN=refine-20260405-001
#   make refine-list
# --------------------------------------------------------------------------

REQUEST ?=
REQUEST_FILE ?=
RUN ?=
AUTO_PUSH ?= 1

.PHONY: refine refine-status refine-resume refine-clean refine-list

refine:
ifdef REQUEST_FILE
	$(PYTHON) $(AUTOMATION)/run_refine.py --request-file "$(REQUEST_FILE)" --auto-push $(AUTO_PUSH) --watch-interval $(WATCH)
else ifdef REQUEST
	$(PYTHON) $(AUTOMATION)/run_refine.py --request "$(REQUEST)" --auto-push $(AUTO_PUSH) --watch-interval $(WATCH)
else
	@echo "Usage:"
	@echo "  make refine REQUEST=\"short request text\""
	@echo "  make refine REQUEST_FILE=path/to/request.md"
	@echo "  make refine REQUEST_FILE=path/to/request.md AUTO_PUSH=1"
	@exit 1
endif

refine-status:
ifndef RUN
	$(error RUN is required. Usage: make refine-status RUN=refine-20260405-001)
endif
	$(PYTHON) $(AUTOMATION)/run_refine.py --run $(RUN) --status

refine-resume:
ifndef RUN
	$(error RUN is required. Usage: make refine-resume RUN=refine-20260405-001)
endif
	$(PYTHON) $(AUTOMATION)/run_refine.py --run $(RUN) --resume

refine-clean:
ifndef RUN
	$(error RUN is required. Usage: make refine-clean RUN=refine-20260405-001)
endif
	$(PYTHON) $(AUTOMATION)/run_refine.py --run $(RUN) --clean

refine-list:
	$(PYTHON) $(AUTOMATION)/run_refine.py --list
