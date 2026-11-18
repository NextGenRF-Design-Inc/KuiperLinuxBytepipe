wrkDir:=${PWD}
srcDir:=$(dir $(lastword $(MAKEFILE_LIST)))
hdlDir:=$(wrkDir)/Adi/hdl
whichVivado:= $(shell which vivado) |rev | cut -d'/' -f3- |rev
vivadoDir=$(shell echo $(whichVivado))
DEV := $(shell bash -c 'read -p "Select Device [ xczu3cg, xczu3eg, xczu2cg, xczu2eg ]: " dev; echo $$dev-sbva484-1-e')
mode ?= lvds
XSA_NAME ?= system_top.xsa

.PHONY:	all

all: directories adi_hdl ip build

directories:
	@echo 'Source Directory: $(srcDir)'
	@echo 'Build Directory: $(wrkDir)'
	@echo 'Vivado Directory: ' $(vivadoDir)

boards:
	cp -r $(srcDir)/../boards/bytepipe_3cg_som $(vivadoDir)/data/boards/board_files/

ip:
	$(MAKE) -C $(wrkDir)/Adi/hdl/library/util_pack/util_upack2 xilinx || exit $$?;
	$(MAKE) -C $(wrkDir)/Adi/hdl/library/util_pack/util_cpack2 xilinx || exit $$?;
	$(MAKE) -C $(wrkDir)/Adi/hdl/library/sysid_rom xilinx || exit $$?;
	$(MAKE) -C $(wrkDir)/Adi/hdl/library/axi_sysid xilinx || exit $$?;
	$(MAKE) -C $(wrkDir)/Adi/hdl/library/axi_dmac xilinx || exit $$?;
	$(MAKE) -C $(wrkDir)/Adi/hdl/library/axi_adrv9001 xilinx || exit $$?;

build:
	vivado -mode batch -nojournal -source $(srcDir)/make.tcl -tclargs $(mode) $(DEV) $(XSA_NAME)
adi_hdl: | $(hdlDir)

$(hdlDir):
	@mkdir -p $(hdlDir)
	git clone --branch hdl_2023_r2 https://github.com/analogdevicesinc/hdl.git $(hdlDir)
	bash -c 'cd $(hdlDir); git am ../../$(srcDir)/0001-Bytepipe-LVDS-inversion-support.patch'





