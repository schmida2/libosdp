/*
 * Copyright (c) 2019 Siddharth Chandrasekaran
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef _OSDPCTL_COMMON_H_
#define _OSDPCTL_COMMON_H_

#include <stdint.h>
#include <osdp.h>

#define CONFIG_FILE_PATH_LENGTH		128
#define ARG_UNUSED(x)			(void)(x)

enum config_osdp_mode_e {
	CONFIG_MODE_CP=1,
	CONFIG_MODE_PD
};

enum config_channel_topology_e {
	CONFIG_CHANNEL_TOPOLOGY_CHAIN=1,
	CONFIG_CHANNEL_TOPOLOGY_STAR
};

enum config_channel_type_e {
	CONFIG_CHANNEL_TYPE_UART=1,
	CONFIG_CHANNEL_TYPE_MSGQ,
	CONFIG_CHANNEL_TYPE_SENTINEL
};

struct config_pd_s {
	char *channel_device;
	int channel_type;
	int channel_speed;

	int address;
	int is_pd_mode;

	struct pd_id id;
	struct pd_cap cap[CAP_SENTINEL];
};

struct config_cp_s {
	uint8_t master_key[16];
};

struct config_s {
	/* ini section: "^GLOBAL" */
	int mode;
	int num_pd;
	int log_level;
	int conn_topology;

	/* ini section: "^CP" */
	struct config_cp_s cp;

	/* ini section: "^PD(-[0-9]+)?" */
	struct config_pd_s *pd;

	/* cli_args */
	int dump_config;
	char *config_file;
};

extern struct config_s g_config;

void config_print(struct config_s *config);
void config_parse(const char *filename, struct config_s *config);

// from strutils.c

int atohstr(char *hstr, const uint8_t *arr, const int arr_len);
int hstrtoa(uint8_t *arr, const char *hstr);
int safe_atoi(const char *a, int *i);
void remove_spaces(char *str);

// command handlers
int cmd_handler_start(int argc, char *argv[], struct config_s *c);

// from channel*.c

extern struct channel_ops_s channel_uart;
extern struct channel_ops_s channel_msgq;

struct channel_ops_s {
	int (*send)(void *data, uint8_t *buf, int len);
	int (*recv)(void *data, uint8_t *buf, int len);
	void (*flush)(void *data);
	int (*setup)(void **data, struct config_pd_s *p);
	void (*teardown)(void *data);
};

int channel_setup(struct osdp_channel *c, struct config_pd_s *p);
void channel_teardown(struct osdp_channel *c, struct config_pd_s *p);

#endif