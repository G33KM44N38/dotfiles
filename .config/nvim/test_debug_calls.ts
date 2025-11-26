// Test file for debug_print.lua unit tests
// Contains various console statements to test detection

function testFunction() {
  console.log("This is a log statement");
  const x = 5;
  console.warn("This is a warning");
  
  if (x > 3) {
    console.error("This is an error");
    console.debug("This is a debug statement");
  }
}

export function anotherTest() {
  console.log("Multiple logs");
  console.log("Second log");
  console.warn("Warning in export");
}

const arrowFunc = () => {
  console.log("Log in arrow function");
};

class MyClass {
  method() {
    console.log("Log in class method");
    console.warn("Warn in class method");
  }
}
