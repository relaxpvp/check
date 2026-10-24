export default {
  async fetch() {
    const r = await fetch("https://raw.githubusercontent.com/relaxpvp/check/main/check.ps1");
    return new Response(r.body, {
      status: r.status,
      headers: {
        "content-type": "text/plain; charset=utf-8",
        "cache-control": "no-cache",
      },
    });
  },
};
