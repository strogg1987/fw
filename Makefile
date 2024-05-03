# Be silent per default, but 'make V=1' will show all compiler calls.
ifneq ($(V),1)
Q		:= @
NULL	:= 2>/dev/null
endif
LIBNAME		= opencm3_stm32g0
DEFS		+= -DSTM32G0
DEVICE		= stm32g070rb
###############################################################################
# Executables

PREFIX	?= arm-none-eabi-

CC		:= $(PREFIX)gcc
CXX		:= $(PREFIX)g++
LD		:= $(PREFIX)gcc
AR		:= $(PREFIX)ar
AS		:= $(PREFIX)as
OBJCOPY	:= $(PREFIX)objcopy
OBJDUMP	:= $(PREFIX)objdump

OPT		:= -Og
DEBUG	:= -ggdb3
CSTD	?= -std=c99

OPENCM3_DIR ?= ./libopencm3
BINARY ?= target

###############################################################################
# Source files

AUTO_SRC_DIRS	= ./src
AUTO_SRCS		= $(shell find $(AUTO_SRC_DIRS) -name *.cpp -or -name *.c -or -name *.s)

FREERTOS_DIR	= ./FreeRTOS
FREERTOS_PORT	= $(FREERTOS_DIR)/ports/$(genlink_family)
FREERTOS_SRC	= $(wildcard $(FREERTOS_DIR)/FreeRTOS-Kernel/*.c) $(wildcard $(FREERTOS_PORT)/*.c)
FREERTOS_INC	= -I$(FREERTOS_DIR)/FreeRTOS-Kernel/include -I$(FREERTOS_PORT)

SRCS		= $(AUTO_SRCS) $(FREERTOS_SRC)

OBJS		= $(addsuffix .o,$(basename $(SRCS)))

include $(OPENCM3_DIR)/mk/genlink-config.mk

###############################################################################
# C flags

TGT_CFLAGS	+= $(OPT) $(CSTD) $(DEBUG)
TGT_CFLAGS	+= $(ARCH_FLAGS)
TGT_CFLAGS	+= -Wextra -Wshadow -Wimplicit-function-declaration
TGT_CFLAGS	+= -Wredundant-decls -Wmissing-prototypes -Wstrict-prototypes
TGT_CFLAGS	+= -fno-common -ffunction-sections -fdata-sections

###############################################################################
# C++ flags

TGT_CXXFLAGS	+= $(OPT) $(CXXSTD) $(DEBUG)
TGT_CXXFLAGS	+= $(ARCH_FLAGS)
TGT_CXXFLAGS	+= -Wextra -Wshadow -Wredundant-decls  -Weffc++
TGT_CXXFLAGS	+= -fno-common -ffunction-sections -fdata-sections

###############################################################################
# C & C++ preprocessor common flags

TGT_CPPFLAGS	+= -MD
TGT_CPPFLAGS	+= -Wall -Wundef
TGT_CPPFLAGS	+= $(DEFS)
TGT_CPPFLAGS	+= $(FREERTOS_INC)

###############################################################################
# Linker flags

TGT_LDFLAGS		+= --static -nostartfiles
TGT_LDFLAGS		+= -T$(LDSCRIPT)
TGT_LDFLAGS		+= $(ARCH_FLAGS) $(DEBUG)
TGT_LDFLAGS		+= -Wl,-Map=$(*).map -Wl,--cref
TGT_LDFLAGS		+= -Wl,--gc-sections
ifeq ($(V),99)
TGT_LDFLAGS		+= -Wl,--print-gc-sections
endif

###############################################################################
# Used libraries

LDLIBS		+= -Wl,--start-group -lc -lgcc -lnosys -Wl,--end-group

###############################################################################

all: elf

elf: $(BINARY).elf
bin: $(BINARY).bin
hex: $(BINARY).hex
srec: $(BINARY).srec
list: $(BINARY).list
GENERATED_BINARIES=$(BINARY).elf $(BINARY).bin $(BINARY).hex $(BINARY).srec $(BINARY).list $(BINARY).map

# Define a helper macro for debugging make errors online
# you can type "make print-OPENCM3_DIR" and it will show you
# how that ended up being resolved by all of the included
# makefiles.
print-%:
	@echo $*=$($*)

images: $(BINARY).images

include $(OPENCM3_DIR)/mk/genlink-rules.mk

$(OPENCM3_DIR)/lib/lib$(LIBNAME).a:
ifeq (,$(wildcard $@))
	$(warning $(LIBNAME).a not found, attempting to rebuild in $(OPENCM3_DIR))
	$(MAKE) -C $(OPENCM3_DIR)
endif

%.images: %.bin %.hex %.srec %.list %.map
	@printf "*** $* images generated ***\n"

%.bin: %.elf
	@printf "  OBJCOPY $(*).bin\n"
	$(Q)$(OBJCOPY) -Obinary $(*).elf $(*).bin

%.hex: %.elf
	@printf "  OBJCOPY $(*).hex\n"
	$(Q)$(OBJCOPY) -Oihex $(*).elf $(*).hex

%.srec: %.elf
	@printf "  OBJCOPY $(*).srec\n"
	$(Q)$(OBJCOPY) -Osrec $(*).elf $(*).srec

%.list: %.elf
	@printf "  OBJDUMP $(*).list\n"
	$(Q)$(OBJDUMP) -S $(*).elf > $(*).list

%.elf %.map: $(OBJS) $(LDSCRIPT) $(OPENCM3_DIR)/lib/lib$(LIBNAME).a
	@printf "  LD      $(*).elf\n"
	$(Q)$(LD) $(TGT_LDFLAGS) $(LDFLAGS) $(OBJS) $(LDLIBS) -o $(*).elf

%.o: %.c
	@printf "  CC      $(*).c\n"
	$(Q)$(CC) $(TGT_CFLAGS) $(CFLAGS) $(TGT_CPPFLAGS) $(CPPFLAGS) -o $(*).o -c $(*).c

%.o: %.cxx
	@printf "  CXX     $(*).cxx\n"
	$(Q)$(CXX) $(TGT_CXXFLAGS) $(CXXFLAGS) $(TGT_CPPFLAGS) $(CPPFLAGS) -o $(*).o -c $(*).cxx

%.o: %.cpp
	@printf "  CXX     $(*).cpp\n"
	$(Q)$(CXX) $(TGT_CXXFLAGS) $(CXXFLAGS) $(TGT_CPPFLAGS) $(CPPFLAGS) -o $(*).o -c $(*).cpp

clean:
	@printf "  CLEAN\n"
	$(Q)$(RM) $(GENERATED_BINARIES) generated.* $(OBJS) $(OBJS:%.o=%.d)



-include $(OBJS:.o=.d)

###
## CUSTOM COMMANDS
###

# Flash with J-Link
# Configure device name, everything else should remain the same
jflash: JFlashExe
	JLinkExe -commanderscript $<
# Change to yours
device = STM32G070RB
# First create a file with all commands
JFlashExe: target.bin
	@touch $@
	@echo device $(device) > $@
	@echo -e si 1'\n'speed 4000 >> $@
	@echo loadbin $< 0x8000000 >> $@
	@echo -e r'\n'g'\n'qc >> $@

# FLash with ST-LINK
stflash: 
	st-flash --reset write target.bin 0x8000000

# Flash with UART module
# If you have problem with flashing but it does connect,
# remove '-e 0' so that it will erase flash contents and
# flash firmware fresh
uflash: $(BUILD_DIR)/$(TARGET).bin
	# This one is used if you have UART module with RTS and DTR pins
	stm32flash -b 115200 -e 0 -R -i rts,dtr,-rts:rts,-dtr,-rts -v -w $< $(PORT)
	# Else use this one and manualy set your MCU to bootloader mode
	#stm32flash -b 115200 -e 0 -v -w $< $(PORT)
	
.PHONY: images clean elf bin hex srec list jflash stflash uflash