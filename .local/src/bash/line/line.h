#ifndef LINE_H
#define LINE_H

#include <config.h>

#include <stdio.h>
#include <string.h>

#include "bashansi.h"
#include "builtins.h"
#include "shell.h"
#include "common.h"

#include <readline/readline.h>
#include <readline/history.h>

/* INFO: fc 06sep26 bash exports these but ships no header for them */
extern int find_reserved_word(char *);
extern char *find_user_command(const char *);
extern char *bash_tilde_expand(const char *, int);
extern int bash_readline_initialized;
extern void initialize_readline(void);
extern int autocd;
extern int interactive_comments;

#define RESET "\033[0m"
#define SAVE_CURSOR "\0337"
#define RESTORE_CURSOR "\0338"
#define ERASE_TO_END_OF_ROW "\033[K"

int columns_within(const char *s, int n, int limit, int *bytes);
int screen_measure(void);
void screen_move_to(int offset);
int screen_room_after(int offset);

void paint_highlights(void);

void paint_suggestion(void);
void withdraw_suggestion(void);
void erase_suggestion(void);
void erase_suggestion_after_echo(void);
int forward_char_or_accept(int count, int key);
int end_of_line_or_accept(int count, int key);
int forward_word_or_accept_word(int count, int key);

#endif
