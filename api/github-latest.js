export default async function handler(req, res) {
  const response = await fetch('https://api.github.com/repos/madoiscool/ltsteamplugin/releases/latest');
  const data = await response.json();
  res.status(200).json(data);
}
