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
