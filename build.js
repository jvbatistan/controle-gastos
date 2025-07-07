// build.js (completo)
const path = require("path");
const esbuild = require('esbuild');
const sassPlugin = require('esbuild-plugin-sass');

const isWatch = process.argv.includes('--watch');

const options = {
  entryPoints: [
    'app/javascript/application.js',
    'app/javascript/styles/application.scss',
  ],
  bundle: true,
  outdir: 'app/assets/builds',
  plugins: [sassPlugin()],
  loader: {
    '.js': 'jsx',
    '.scss': 'css',
    '.css': 'css',
    '.woff': 'file',
    '.woff2': 'file',
    '.ttf': 'file',
    '.eot': 'file',
    '.svg': 'file',
  },
  sourcemap: false,
  minify: true,
  assetNames: 'assets/[name]-[hash]', // adiciona cache bust
};

if (isWatch) {
  esbuild.context(options).then(ctx => {
    ctx.watch();
    console.log('👀 Assistindo alterações...');
  }).catch(err => {
    console.error(err);
    process.exit(1);
  });
} else {
  esbuild.build(options).catch(() => process.exit(1));
}