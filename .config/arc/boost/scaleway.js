(function () {
  "use strict";

  let lastKeyPress = "";
  let timer;

  function navigateTo(href) {
    const els = document.querySelectorAll(`a[href='${href}']`);
    if (els.length > 0) {
      els[0].click();
    }
  }
  function ClickOnId(id) {
    const element = document.getElementById(id);
    element.click();
  }

  function navigateToHome() {
    navigateTo("/");
  }

  function navigateToContainers() {
    ClickOnId("containers");
  }

  function navigateToRegistry() {
    ClickOnId("registry");
  }

  function navigateToObject() {
    ClickOnId("objectStorage");
  }
  // rdb
  function navigateToDatabase() {
    ClickOnId("rdb");
  }

  document.addEventListener("keydown", function (e) {
    // Ignore keypress if user is typing in an input field
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") {
      return;
    }

    clearTimeout(timer);

    const keyMappings = {
      gh: () => {
        navigateToHome();
      },
      gc: () => {
        navigateToContainers();
      },
      gr: () => {
        navigateToRegistry();
      },
      go: () => {
        navigateToObject();
      },
      gd: () => {
        navigateToDatabase();
      },
    };

    if (e.key === "g") {
      lastKeyPress = "g";
    } else if (lastKeyPress === "g") {
      const action = keyMappings[`g${e.key}`];
      if (action) {
        action();
        lastKeyPress = "";
      } else {
        lastKeyPress = "";
      }
    } else {
      lastKeyPress = "";
    }

    timer = setTimeout(() => {
      lastKeyPress = "";
    }, 1000); // 1 second window to complete the shortcut
  });
})();
