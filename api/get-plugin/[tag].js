export default async function handler(req, res) {
  const { tag } = req.query;
  const url = `https://github.com/madoiscool/ltsteamplugin/releases/download/${tag}/ltsteamplugin.zip`;
  const response = await fetch(url);

  if (!response.ok) {
    res.status(response.status).send('Failed to fetch file.');
    return;
  }
  res.setHeader('Content-Type', 'application/zip');
  res.setHeader('Content-Disposition', 'attachment; filename="ltsteamplugin.zip"');
  const fileBuffer = await response.arrayBuffer();
  res.send(Buffer.from(fileBuffer));
}
