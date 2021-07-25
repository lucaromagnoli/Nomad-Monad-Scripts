import reapy


class ResampleTrack(reapy.Track):
    def __init__(self, source_track: reapy.Track, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.source_track = source_track

    def __repr__(self):
        return f'ResampleTrack(source_track={self.source_track.name})'

    @classmethod
    def from_source_track(cls, project: reapy.Project, source_track: reapy.Track,
                          tag: str = '[RSMPL]'):
        project.add_track(
            index=source_track.index + 1,
            name=f'{source_track.name} {tag}'
        )
        return cls(source_track=source_track,
                   id=source_track.index + 1,
                   project=source_track.project)
