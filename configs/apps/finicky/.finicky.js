// Use https://finicky-kickstart.now.sh to generate basic configuration
// Learn more about configuration options: https://github.com/johnste/finicky/wiki/Configuration

module.exports = {
  defaultBrowser: {
    name: "Google Chrome",
    profile: "Profile 1",
  },
  options: {
    hideIcon: false,
    checkForUpdate: true,
  },
  handlers: [
    {
      match: ({ opener }) =>
        ["Slack", "Xcode"].includes(opener.name),
      browser: {
        name: "Google Chrome",
        profile: "Profile 1",
      },
    },
    {
      match: ({ opener }) =>
        ["Stache"].includes(opener.name),
      browser: {
        name: "Google Chrome",
        profile: "Profile 2",
      },
    },
    {
      match: ({ url }) => url.protocol === "slack",
      browser: "/Applications/Slack.app",
    },
    {
      match: ({ url }) => url.protocol === "globalprotectcallback",
      browser: "/Applications/GlobalProtect.app",
    },
    {
      match: /^https?:\/\/linkedin\.com\/.*$/,
	  browser: {
        name: "Google Chrome",
        profile: "Profile 2",
      }
    },
    {
      match: /airbnb\.com/,
	  browser: {
        name: "Google Chrome",
        profile: "Profile 1",
      }
    },
    {
    match: /zoom\.us\/join/,
    browser: "us.zoom.xos"
    }
  ],
  rewrite: [{
    match: ({
      url
    }) => url.host.includes("zoom.us") && url.pathname.includes("/j/"),
    url({
      url
    }) {
      try {
        var pass = '&pwd=' + url.search.match(/pwd=(\w*)/)[1];
      } catch {
        var pass = ""
      }
      var conf = 'confno=' + url.pathname.match(/\/j\/(\d+)/)[1];
      return {
        search: conf + pass,
        pathname: '/join',
        protocol: "zoommtg"
      }
    }
  }]

}