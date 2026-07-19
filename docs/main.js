(function () {
  var cmd = document.getElementById('install-cmd');
  var btn = document.getElementById('copy-btn');
  var label = btn.querySelector('.copy-label');

  if (!cmd || !btn) return;

  btn.addEventListener('click', function () {
    var text = cmd.textContent.trim();

    function onSuccess() {
      btn.classList.add('copied');
      label.textContent = 'Copied!';
      setTimeout(function () {
        btn.classList.remove('copied');
        label.textContent = 'Copy';
      }, 2000);
    }

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(onSuccess).catch(fallback);
    } else {
      fallback();
    }

    function fallback() {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.position = 'absolute';
      ta.style.left = '-9999px';
      document.body.appendChild(ta);
      ta.select();
      try {
        document.execCommand('copy');
        onSuccess();
      } catch (e) {
        label.textContent = 'Select & copy';
      }
      document.body.removeChild(ta);
    }
  });
})();
