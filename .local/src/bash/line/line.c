/* Highlights the command line and suggests from history in grey, as zsh does. Loaded with
   `enable -f`, so it runs inside bash and can ask bash itself what a word means. */

#include "line.h"

#define CTRL_RIGHT "\033[1;5C"

static int highlighting, suggesting;
static rl_voidfunc_t *painted_over;
static rl_getc_func_t *read_key_underneath;
static rl_voidfunc_t *release_terminal_underneath;

static void redisplay(void)
{
  painted_over();
  withdraw_suggestion();

  if (rl_end == 0 || screen_measure() < 0)
    return;
  if (highlighting)
    paint_highlights();
  if (suggesting && RL_ISSTATE(RL_STATE_TERMPREPPED))
    paint_suggestion();
  fflush(rl_outstream);
}

/* Readline believes the row past the line is blank, so the grey goes before any key acts. */
static int read_key(FILE *stream)
{
  int key = read_key_underneath(stream);

  erase_suggestion();
  return key;
}

/* Ctrl-C and Ctrl-Z leave the line without another key, but always through here. */
static void release_terminal(void)
{
  erase_suggestion_after_echo();
  release_terminal_underneath();
}

static void rebind(rl_command_func_t *from, rl_command_func_t *to)
{
  Keymap map = rl_get_keymap();
  char **keys = rl_invoking_keyseqs_in_map(from, map);
  int i;

  if (!keys)
    return;
  for (i = 0; keys[i]; i++) {
    rl_bind_keyseq_in_map(keys[i], to, map);
    free(keys[i]);
  }
  free(keys);
}

static void rebind_key(const char *key, rl_command_func_t *from, rl_command_func_t *to)
{
  Keymap map = rl_get_keymap();

  if (rl_function_of_keyseq(key, map, NULL) == from)
    rl_bind_keyseq_in_map(key, to, map);
}

static void hook(void)
{
  /* INFO: fc 25sep26 readline skips terminfo while a custom redisplay function is set */
  if (!bash_readline_initialized)
    initialize_readline();
  if (rl_redisplay_function != redisplay) {
    painted_over = rl_redisplay_function;
    rl_redisplay_function = redisplay;
  }
  if (rl_getc_function != read_key) {
    read_key_underneath = rl_getc_function;
    rl_getc_function = read_key;
  }
  if (rl_deprep_term_function != release_terminal) {
    release_terminal_underneath = rl_deprep_term_function;
    rl_deprep_term_function = release_terminal;
  }
  rebind(rl_forward_char, forward_char_or_accept);
  rebind(rl_end_of_line, end_of_line_or_accept);
  rebind_key(CTRL_RIGHT, rl_forward_word, forward_word_or_accept_word);
}

static void unhook(void)
{
  if (rl_redisplay_function == redisplay)
    rl_redisplay_function = painted_over;
  if (rl_getc_function == read_key)
    rl_getc_function = read_key_underneath;
  if (rl_deprep_term_function == release_terminal)
    rl_deprep_term_function = release_terminal_underneath;
  rebind(forward_char_or_accept, rl_forward_char);
  rebind(end_of_line_or_accept, rl_end_of_line);
  rebind_key(CTRL_RIGHT, forward_word_or_accept_word, rl_forward_word);
}

static int switch_value(WORD_LIST *list, int *value)
{
  if (!list || strcmp(list->word->word, "on") == 0)
    *value = 1;
  else if (strcmp(list->word->word, "off") == 0)
    *value = 0;
  else
    return 0;
  return list == NULL || list->next == NULL;
}

int line_builtin(WORD_LIST *list)
{
  char *word = list ? list->word->word : "on";
  int on;

  if (strcmp(word, "status") == 0) {
    printf("highlight %s\nsuggest %s\n", highlighting ? "on" : "off", suggesting ? "on" : "off");
    return EXECUTION_SUCCESS;
  }
  if (strcmp(word, "highlight") == 0 && switch_value(list->next, &highlighting))
    ;
  else if (strcmp(word, "suggest") == 0 && switch_value(list->next, &suggesting))
    ;
  else if (switch_value(list, &on))
    highlighting = suggesting = on;
  else {
    builtin_usage();
    return EX_USAGE;
  }
  if (highlighting || suggesting)
    hook();
  else
    unhook();
  return EXECUTION_SUCCESS;
}

void line_builtin_unload(char *name)
{
  unhook();
}

char *line_doc[] = {
    "Color the command line as zsh-syntax-highlighting does, and suggest",
    "the newest history entry starting with the line in grey. Right and End",
    "take the suggestion, Ctrl-Right takes its next word.",
    "",
    "Without an argument, or with on or off, both features switch together.",
    (char *)NULL};

struct builtin line_struct = {
    "line", line_builtin, BUILTIN_ENABLED, line_doc,
    "line [on|off|status] | line highlight|suggest [on|off]", 0};
