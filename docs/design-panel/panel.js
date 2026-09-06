/* Friday 5PM: Evacuation — design panel shared behavior.
   Export / clipboard with file:// fallback + feedback copy.
   Race values shown are ILLUSTRATIVE; this file never claims otherwise. */

function feedback(button, okText) {
  const prev = button.textContent;
  button.textContent = okText;
  button.disabled = true;
  setTimeout(() => { button.textContent = prev; button.disabled = false; }, 1600);
}

async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch (e) {
    // file:// / permission fallback: hidden textarea + execCommand
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    let ok = false;
    try { ok = document.execCommand("copy"); } catch (e2) { ok = false; }
    ta.remove();
    return ok;
  }
}

function wireExport(buttonId, getText) {
  const btn = document.getElementById(buttonId);
  if (!btn) return;
  btn.addEventListener("click", async () => {
    const text = getText();
    const ok = await copyText(text);
    feedback(btn, ok ? "Copied ✓" : "Select & copy in dialog");
    if (!ok) {
      const dlg = document.getElementById("export-dialog");
      if (dlg && dlg.showModal) {
        dlg.querySelector("textarea").value = text;
        dlg.showModal();
      }
    }
  });
}
