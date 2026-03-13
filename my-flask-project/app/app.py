from flask import Flask, jsonify, render_template_string, request

app = Flask(__name__)

PAGE_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Auth UI</title>
  <style>
    :root {
      --bg: #f3efe7;
      --panel: rgba(255, 255, 255, 0.86);
      --panel-strong: #ffffff;
      --text: #1d2433;
      --muted: #647089;
      --accent: #d96c3f;
      --accent-dark: #b14f28;
      --line: rgba(29, 36, 51, 0.12);
      --shadow: 0 24px 60px rgba(50, 42, 30, 0.14);
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      font-family: Georgia, "Times New Roman", serif;
      color: var(--text);
      background:
        radial-gradient(circle at top left, rgba(217, 108, 63, 0.24), transparent 32%),
        radial-gradient(circle at bottom right, rgba(28, 78, 110, 0.18), transparent 28%),
        linear-gradient(135deg, #f5f1e9 0%, #efe6d8 48%, #f6f3ed 100%);
      display: grid;
      place-items: center;
      padding: 24px;
    }

    .shell {
      width: min(1080px, 100%);
      background: var(--panel);
      backdrop-filter: blur(14px);
      border: 1px solid rgba(255, 255, 255, 0.6);
      border-radius: 28px;
      box-shadow: var(--shadow);
      overflow: hidden;
      display: grid;
      grid-template-columns: 1.05fr 0.95fr;
    }

    .hero {
      padding: 56px;
      background:
        linear-gradient(180deg, rgba(255,255,255,0.22), rgba(255,255,255,0)),
        linear-gradient(145deg, #1d2433 0%, #31435b 44%, #8c4d38 100%);
      color: #fffaf3;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      gap: 32px;
    }

    .brand {
      display: inline-flex;
      align-items: center;
      gap: 12px;
      font-size: 0.95rem;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .brand-mark {
      width: 42px;
      height: 42px;
      border-radius: 14px;
      display: grid;
      place-items: center;
      background: rgba(255, 255, 255, 0.14);
      border: 1px solid rgba(255, 255, 255, 0.16);
      font-size: 1.1rem;
    }

    .hero-copy h1 {
      font-size: clamp(2.7rem, 5vw, 4.6rem);
      line-height: 0.95;
      margin: 0 0 18px;
      max-width: 9ch;
    }

    .hero-copy p {
      margin: 0;
      max-width: 42ch;
      color: rgba(255, 250, 243, 0.78);
      font-size: 1rem;
      line-height: 1.7;
    }

    .hero-points {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 14px;
    }

    .point {
      padding: 16px;
      border-radius: 18px;
      background: rgba(255, 255, 255, 0.1);
      border: 1px solid rgba(255, 255, 255, 0.12);
    }

    .point strong {
      display: block;
      font-size: 1.15rem;
      margin-bottom: 6px;
    }

    .point span {
      font-size: 0.88rem;
      color: rgba(255, 250, 243, 0.7);
    }

    .panel {
      padding: 40px 32px;
      background: rgba(255, 255, 255, 0.72);
    }

    .tabs {
      display: inline-grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 6px;
      background: rgba(29, 36, 51, 0.06);
      padding: 6px;
      border-radius: 999px;
      margin-bottom: 26px;
    }

    .tab {
      border: 0;
      background: transparent;
      color: var(--muted);
      padding: 11px 22px;
      border-radius: 999px;
      font-size: 0.95rem;
      cursor: pointer;
      text-decoration: none;
      text-align: center;
    }

    .tab.active {
      background: var(--panel-strong);
      color: var(--text);
      box-shadow: 0 8px 20px rgba(29, 36, 51, 0.08);
    }

    .card {
      background: rgba(255, 255, 255, 0.84);
      border: 1px solid var(--line);
      border-radius: 24px;
      padding: 28px;
    }

    .card h2 {
      margin: 0 0 8px;
      font-size: 2rem;
    }

    .lead {
      margin: 0 0 22px;
      color: var(--muted);
      line-height: 1.6;
    }

    .notice {
      padding: 14px 16px;
      border-radius: 16px;
      margin-bottom: 18px;
      font-size: 0.95rem;
      border: 1px solid rgba(217, 108, 63, 0.24);
      background: rgba(217, 108, 63, 0.08);
      color: #8a4327;
    }

    form {
      display: grid;
      gap: 16px;
    }

    .field {
      display: grid;
      gap: 8px;
    }

    label {
      font-size: 0.92rem;
      color: var(--muted);
    }

    input {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 16px;
      padding: 14px 16px;
      font-size: 1rem;
      background: rgba(255, 255, 255, 0.96);
      color: var(--text);
    }

    input:focus {
      outline: 2px solid rgba(217, 108, 63, 0.16);
      border-color: rgba(217, 108, 63, 0.46);
    }

    .row {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 14px;
    }

    .cta {
      border: 0;
      border-radius: 18px;
      padding: 15px 18px;
      font-size: 1rem;
      font-weight: 600;
      color: #fff;
      background: linear-gradient(135deg, var(--accent) 0%, #e08f52 100%);
      cursor: pointer;
      box-shadow: 0 16px 28px rgba(217, 108, 63, 0.22);
    }

    .meta {
      margin-top: 18px;
      color: var(--muted);
      font-size: 0.92rem;
      line-height: 1.6;
    }

    @media (max-width: 900px) {
      .shell {
        grid-template-columns: 1fr;
      }

      .hero,
      .panel {
        padding: 28px;
      }

      .hero-points,
      .row {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <main class="shell">
    <section class="hero">
      <div>
        <div class="brand">
          <div class="brand-mark">A</div>
          <span>Atlas Access</span>
        </div>
        <div class="hero-copy">
          <h1>Sign in or create your space.</h1>
          <p>
            A polished auth-style landing page for your Flask deployment. It is UI only,
            so forms simulate login and signup without storing anything.
          </p>
        </div>
      </div>
      <div class="hero-points">
        <div class="point">
          <strong>Fast</strong>
          <span>Single-file Flask page, easy to deploy.</span>
        </div>
        <div class="point">
          <strong>Clean</strong>
          <span>Modern layout with simple responsive styling.</span>
        </div>
        <div class="point">
          <strong>Safe</strong>
          <span>No database, no sessions, no persistence.</span>
        </div>
      </div>
    </section>

    <section class="panel">
      <nav class="tabs">
        <a class="tab {% if mode == 'login' %}active{% endif %}" href="/login">Log In</a>
        <a class="tab {% if mode == 'signup' %}active{% endif %}" href="/signup">Sign Up</a>
      </nav>

      <div class="card">
        <h2>{% if mode == 'login' %}Welcome back{% else %}Create account{% endif %}</h2>
        <p class="lead">
          {% if mode == 'login' %}
          Enter your details to access the demo dashboard.
          {% else %}
          Start with a simple account form for your Flask UI demo.
          {% endif %}
        </p>

        {% if message %}
        <div class="notice">{{ message }}</div>
        {% endif %}

        {% if mode == 'login' %}
        <form method="post">
          <div class="field">
            <label for="email">Email</label>
            <input id="email" name="email" type="email" placeholder="you@example.com" required>
          </div>
          <div class="field">
            <label for="password">Password</label>
            <input id="password" name="password" type="password" placeholder="Enter your password" required>
          </div>
          <button class="cta" type="submit">Log In</button>
        </form>
        {% else %}
        <form method="post">
          <div class="row">
            <div class="field">
              <label for="first_name">First name</label>
              <input id="first_name" name="first_name" type="text" placeholder="Hrushi" required>
            </div>
            <div class="field">
              <label for="last_name">Last name</label>
              <input id="last_name" name="last_name" type="text" placeholder="Gavhane" required>
            </div>
          </div>
          <div class="field">
            <label for="email">Email</label>
            <input id="email" name="email" type="email" placeholder="you@example.com" required>
          </div>
          <div class="field">
            <label for="password">Password</label>
            <input id="password" name="password" type="password" placeholder="Create a password" required>
          </div>
          <button class="cta" type="submit">Create Account</button>
        </form>
        {% endif %}

        <p class="meta">
          Demo only. Submit will show a confirmation message, but nothing is stored.
        </p>
      </div>
    </section>
  </main>
</body>
</html>
"""


def render_auth_page(mode):
    message = None

    if request.method == "POST":
        if mode == "login":
            email = request.form.get("email", "")
            message = f"Login request received for {email}. Authentication is disabled in this demo."
        else:
            first_name = request.form.get("first_name", "")
            email = request.form.get("email", "")
            message = f"Account created for {first_name or 'user'} ({email}) in UI-only demo mode."

    return render_template_string(PAGE_TEMPLATE, mode=mode, message=message)


@app.route("/")
def home():
    return render_auth_page("login")


@app.route("/login", methods=["GET", "POST"])
def login():
    return render_auth_page("login")


@app.route("/signup", methods=["GET", "POST"])
def signup():
    return render_auth_page("signup")


@app.route("/health")
def health():
    return jsonify({"status": "ok"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
