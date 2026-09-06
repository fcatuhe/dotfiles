/* Paints the first word green when bash can run it, red when it cannot. Loaded with
   `enable -f`, so it runs inside bash and can ask bash itself what a word means. */

#include <config.h>

#include <stdio.h>
#include <string.h>
#include <wchar.h>

#include "bashansi.h"
#include "builtins.h"
#include "shell.h"
#include "common.h"

#include <readline/readline.h>

/* INFO: fc 06sep26 bash exports these two but ships no header for them */
extern int find_reserved_word(char *);
extern char *find_user_command(const char *);

#define GREEN "\033[32m"
#define RED "\033[31m"
#define RESET "\033[0m"
#define SAVE_CURSOR "\0337"
#define RESTORE_CURSOR "\0338"

static rl_voidfunc_t *painted_over;

static int word_end(const char *s)
{
  int i = 0;
  while (s[i] && !strchr(" \t\n;|&<>()", s[i]))
    i++;
  return i;
}

static int bash_knows(const char *start, int length)
{
  char word[256], *path;

  if (length <= 0 || length >= (int)sizeof word)
    return 0;
  memcpy(word, start, length);
  word[length] = '\0';

  if (find_reserved_word(word) >= 0 || find_alias(word) || find_function(word) ||
      find_shell_builtin(word))
    return 1;

  path = find_user_command(word);
  if (path) {
    free(path);
    return 1;
  }
  return 0;
}

/* -1 when the text is not decodable. */
static int columns_of(const char *s, int n)
{
  mbstate_t state;
  int width = 0;

  memset(&state, 0, sizeof state);
  while (n > 0) {
    wchar_t wc;
    size_t len = mbrtowc(&wc, s, n, &state);
    int w;

    if (len == 0 || len == (size_t)-1 || len == (size_t)-2)
      return -1;
    w = wcwidth(wc);
    if (w < 0)
      return -1;
    width += w;
    s += len;
    n -= len;
  }
  return width;
}

static int prompt_columns(void)
{
  const char *p = rl_display_prompt;
  const char *line;
  char visible[512];
  int n = 0, hidden = 0;

  if (!p)
    return 0;
  line = strrchr(p, '\n');
  p = line ? line + 1 : p;

  for (; *p && n < (int)sizeof visible - 1; p++) {
    if (*p == RL_PROMPT_START_IGNORE)
      hidden = 1;
    else if (*p == RL_PROMPT_END_IGNORE)
      hidden = 0;
    else if (!hidden)
      visible[n++] = *p;
  }
  visible[n] = '\0';
  return columns_of(visible, n);
}

static void paint_first_word(void)
{
  const char *buf = rl_line_buffer;
  int start = 0, end, rows, cols, prompt, line, from_word;

  painted_over();

  if (!buf || !*buf)
    return;
  while (buf[start] == ' ' || buf[start] == '\t')
    start++;
  end = word_end(buf + start);
  if (end == 0)
    return;

  prompt = prompt_columns();
  line = columns_of(buf, rl_end);
  from_word = columns_of(buf + start, rl_point - start);
  if (prompt < 0 || line < 0 || rl_point < start)
    return;

  /* A wrapped line puts the word on a row a horizontal move cannot reach. */
  rl_get_screen_size(&rows, &cols);
  if (prompt + line >= cols)
    return;

  fprintf(rl_outstream, SAVE_CURSOR);
  if (from_word > 0)
    fprintf(rl_outstream, "\033[%dD", from_word);
  fprintf(rl_outstream, "%s%.*s" RESET RESTORE_CURSOR,
          bash_knows(buf + start, end) ? GREEN : RED, end, buf + start);
  fflush(rl_outstream);
}

static void hook(void)
{
  if (rl_redisplay_function != paint_first_word) {
    painted_over = rl_redisplay_function;
    rl_redisplay_function = paint_first_word;
  }
}

static void unhook(void)
{
  if (rl_redisplay_function == paint_first_word)
    rl_redisplay_function = painted_over;
}

int hl_builtin(WORD_LIST *list)
{
  char *word = list ? list->word->word : "on";

  if (strcmp(word, "on") == 0)
    hook();
  else if (strcmp(word, "off") == 0)
    unhook();
  else if (strcmp(word, "status") == 0)
    printf("%s\n", rl_redisplay_function == paint_first_word ? "on" : "off");
  else {
    builtin_usage();
    return EX_USAGE;
  }
  return EXECUTION_SUCCESS;
}

char *hl_doc[] = {
    "Paint the first word of the command line green when bash can run it,",
    "red when it cannot. Aliases, functions, builtins, reserved words and",
    "commands on PATH all count as runnable.",
    (char *)NULL};

struct builtin hl_struct = {
    "hl", hl_builtin, BUILTIN_ENABLED, hl_doc, "hl [on|off|status]", 0};
