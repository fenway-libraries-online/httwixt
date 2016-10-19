# httwixt

**httwixt** is an extremely simple HTTP server that runs under inetd or xinetd.

Its job is to make files available under a full web server such as Apache or Nginx.

To do this, it creates a subdirectory within a public file space, using an unguessable ("random") name,
and then creates a symlink under it that points to the desired file.

There is no authentication or authorization mechanism -- you must implement that separately if you need it.

Neither is there a mechanism to delete symlinks or the directories they're in
(e.g., after some delay); again, you must implement that yourself (e.g., using
a cron job) if you want this feature.
