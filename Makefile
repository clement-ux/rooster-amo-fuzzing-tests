# Environment Variables
-include .env

# Export Variables
.EXPORT_ALL_VARIABLES:
MAKEFLAGS += --no-print-directory

# Default Target
default:
	forge fmt && forge build

# Installation
install:
	foundryup
	forge soldeer install
	rm -f requirements.txt


# Cleaning Targets
clean:
	rm -f -r out
	rm -f -r cache

clean-all: 
	$(MAKE) clean
	rm -f -r dependencies
	rm -f -r soldeer.lock